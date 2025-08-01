import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category_model.dart';

class CategoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _categoriesCollection = 'categories';
  final String _productsCollection = 'products';

  // Create a new category
  Future<void> createCategory(CategoryModel category) async {
    try {
      final docRef = _firestore.collection(_categoriesCollection).doc();
      final storedCategory = category.copyWith(
        id: docRef.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: category.createdBy, // Preserve the createdBy field
      );
      await docRef.set(storedCategory.toMap());
    } catch (e) {
      throw Exception('Failed to create category: $e');
    }
  }

  // Get category by ID
  Future<CategoryModel?> getCategoryById(String categoryId) async {
    try {
      final doc = await _firestore
          .collection(_categoriesCollection)
          .doc(categoryId)
          .get();
      if (doc.exists) {
        return CategoryModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get category: $e');
    }
  }

  // Get all categories
  Future<List<CategoryModel>> getAllCategories() async {
    try {
      final query = await _firestore
          .collection(_categoriesCollection)
          .orderBy('createdAt', descending: false)
          .get();

      return query.docs
          .map((doc) => CategoryModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get categories: $e');
    }
  }

  // Get active categories only
  Future<List<CategoryModel>> getActiveCategories() async {
    try {
      final query = await _firestore
          .collection(_categoriesCollection)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: false)
          .get();

      return query.docs
          .map((doc) => CategoryModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get active categories: $e');
    }
  }

  // Get inactive categories
  Future<List<CategoryModel>> getInactiveCategories() async {
    try {
      final query = await _firestore
          .collection(_categoriesCollection)
          .where('isActive', isEqualTo: false)
          .orderBy('createdAt', descending: false)
          .get();

      return query.docs
          .map((doc) => CategoryModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get inactive categories: $e');
    }
  }

  // Get parent categories (categories with no parent)
  Future<List<CategoryModel>> getParentCategories() async {
    try {
      final query = await _firestore
          .collection(_categoriesCollection)
          .where('parentCategory', isNull: true)
          .get();

      // Sort in memory to avoid composite index requirement
      final categories = query.docs
          .map((doc) => CategoryModel.fromJson(doc.data()))
          .toList();

      categories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return categories;
    } catch (e) {
      throw Exception('Failed to get parent categories: $e');
    }
  }

  // Get subcategories of a parent category
  Future<List<CategoryModel>> getSubcategories(String parentCategoryId) async {
    try {
      final query = await _firestore
          .collection(_categoriesCollection)
          .where('parentCategory', isEqualTo: parentCategoryId)
          .get();

      // Sort in memory to avoid composite index requirement
      final categories = query.docs
          .map((doc) => CategoryModel.fromJson(doc.data()))
          .toList();

      categories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return categories;
    } catch (e) {
      throw Exception('Failed to get subcategories: $e');
    }
  }

  // Get category hierarchy (parent with all its subcategories)
  Future<Map<String, dynamic>> getCategoryHierarchy(
    String parentCategoryId,
  ) async {
    try {
      final parent = await getCategoryById(parentCategoryId);
      if (parent == null) {
        throw Exception('Parent category not found');
      }

      final subcategories = await getSubcategories(parentCategoryId);

      return {'parent': parent, 'subcategories': subcategories};
    } catch (e) {
      throw Exception('Failed to get category hierarchy: $e');
    }
  }

  // Update category
  Future<void> updateCategory(CategoryModel category) async {
    try {
      final updatedCategory = category.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection(_categoriesCollection)
          .doc(category.id)
          .update(updatedCategory.toMap());
    } catch (e) {
      throw Exception('Failed to update category: $e');
    }
  }

  // Activate category and its products
  Future<void> activateCategory(String categoryId, String modifiedBy) async {
    try {
      final batch = _firestore.batch();

      // Update category status
      final categoryRef = _firestore
          .collection(_categoriesCollection)
          .doc(categoryId);
      batch.update(categoryRef, {
        'isActive': true,
        'lastModifiedBy': modifiedBy,
        'updatedAt': DateTime.now(),
      });

      // Get all products in this category that are currently inactive
      final productsQuery = await _firestore
          .collection(_productsCollection)
          .where('categoryId', isEqualTo: categoryId)
          .where('isActive', isEqualTo: false) // Only get inactive products
          .get();

      // Check if there are products to activate
      if (productsQuery.docs.isNotEmpty) {
        for (var productDoc in productsQuery.docs) {
          batch.update(productDoc.reference, {
            'isActive': true,
            'lastModifiedBy': modifiedBy,
            'updatedAt': DateTime.now(),
          });
        }
      } else {}

      // Also activate subcategories and their products
      await _activateSubcategoriesRecursively(categoryId, modifiedBy, batch);

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to activate category: $e');
    }
  }

  // Deactivate category and its products
  Future<void> deactivateCategory(String categoryId, String modifiedBy) async {
    try {
      final batch = _firestore.batch();

      // Update category status
      final categoryRef = _firestore
          .collection(_categoriesCollection)
          .doc(categoryId);
      batch.update(categoryRef, {
        'isActive': false,
        'lastModifiedBy': modifiedBy,
        'updatedAt': DateTime.now(),
      });

      // Get all products in this category that are currently active
      final productsQuery = await _firestore
          .collection(_productsCollection)
          .where('categoryId', isEqualTo: categoryId)
          .where('isActive', isEqualTo: true) // Only get active products
          .get();

      // Check if there are products to deactivate
      if (productsQuery.docs.isNotEmpty) {
        for (var productDoc in productsQuery.docs) {
          batch.update(productDoc.reference, {
            'isActive': false,
            'lastModifiedBy': modifiedBy,
            'updatedAt': DateTime.now(),
          });
        }
      } else {}

      // Also deactivate subcategories and their products
      await _deactivateSubcategoriesRecursively(categoryId, modifiedBy, batch);

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to deactivate category: $e');
    }
  }

  // Helper method to get product count in category
  Future<int> getProductCountInCategory(
    String categoryId, {
    bool? isActive,
  }) async {
    try {
      Query query = _firestore
          .collection(_productsCollection)
          .where('categoryId', isEqualTo: categoryId);

      if (isActive != null) {
        query = query.where('isActive', isEqualTo: isActive);
      }

      final productsQuery = await query.get();
      return productsQuery.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // Helper method to recursively activate subcategories
  Future<void> _activateSubcategoriesRecursively(
    String parentCategoryId,
    String modifiedBy,
    WriteBatch batch,
  ) async {
    final subcategories = await getSubcategories(parentCategoryId);

    for (var subcategory in subcategories) {
      // Activate subcategory
      final subcategoryRef = _firestore
          .collection(_categoriesCollection)
          .doc(subcategory.id);
      batch.update(subcategoryRef, {
        'isActive': true,
        'lastModifiedBy': modifiedBy,
        'updatedAt': DateTime.now(),
      });

      // Activate products in subcategory
      final productsQuery = await _firestore
          .collection(_productsCollection)
          .where('categoryId', isEqualTo: subcategory.id)
          .get();

      for (var productDoc in productsQuery.docs) {
        batch.update(productDoc.reference, {
          'isActive': true,
          'lastModifiedBy': modifiedBy,
          'updatedAt': DateTime.now(),
        });
      }

      // Recursively activate nested subcategories
      await _activateSubcategoriesRecursively(
        subcategory.id,
        modifiedBy,
        batch,
      );
    }
  }

  // Helper method to recursively deactivate subcategories
  Future<void> _deactivateSubcategoriesRecursively(
    String parentCategoryId,
    String modifiedBy,
    WriteBatch batch,
  ) async {
    final subcategories = await getSubcategories(parentCategoryId);

    for (var subcategory in subcategories) {
      // Deactivate subcategory
      final subcategoryRef = _firestore
          .collection(_categoriesCollection)
          .doc(subcategory.id);
      batch.update(subcategoryRef, {
        'isActive': false,
        'lastModifiedBy': modifiedBy,
        'updatedAt': DateTime.now(),
      });

      // Deactivate products in subcategory
      final productsQuery = await _firestore
          .collection(_productsCollection)
          .where('categoryId', isEqualTo: subcategory.id)
          .get();

      for (var productDoc in productsQuery.docs) {
        batch.update(productDoc.reference, {
          'isActive': false,
          'lastModifiedBy': modifiedBy,
          'updatedAt': DateTime.now(),
        });
      }

      // Recursively deactivate nested subcategories
      await _deactivateSubcategoriesRecursively(
        subcategory.id,
        modifiedBy,
        batch,
      );
    }
  }

  // Delete category (soft delete by deactivating, or hard delete)
  Future<void> deleteCategory(
    String categoryId, {
    bool hardDelete = false,
  }) async {
    try {
      if (hardDelete) {
        // Check if category has subcategories
        final subcategories = await getSubcategories(categoryId);
        if (subcategories.isNotEmpty) {
          throw Exception(
            'Cannot delete category with subcategories. Delete subcategories first.',
          );
        }

        // Check if category has products
        final productsQuery = await _firestore
            .collection(_productsCollection)
            .where('categoryId', isEqualTo: categoryId)
            .limit(1)
            .get();

        if (productsQuery.docs.isNotEmpty) {
          throw Exception(
            'Cannot delete category with products. Move or delete products first.',
          );
        }

        // Hard delete
        await _firestore
            .collection(_categoriesCollection)
            .doc(categoryId)
            .delete();
      } else {
        // Soft delete by deactivating
        await deactivateCategory(categoryId, 'system');
      }
    } catch (e) {
      throw Exception('Failed to delete category: $e');
    }
  }

  // Check if category name already exists (case-insensitive)
  Future<bool> isCategoryNameExists(
    String name, {
    String? excludeCategoryId,
    String? parentCategoryId,
  }) async {
    try {
      Query query = _firestore.collection(_categoriesCollection);

      // Filter by parent category if specified
      if (parentCategoryId != null) {
        query = query.where('parentCategory', isEqualTo: parentCategoryId);
      } else {
        query = query.where('parentCategory', isNull: true);
      }

      final querySnapshot = await query.get();

      final normalizedName = name.toLowerCase().trim();

      for (var doc in querySnapshot.docs) {
        final category = CategoryModel.fromJson(
          doc.data() as Map<String, dynamic>,
        );

        // Skip the category being updated
        if (excludeCategoryId != null && category.id == excludeCategoryId) {
          continue;
        }

        // Check for case-insensitive match
        if (category.name.toLowerCase().trim() == normalizedName) {
          return true;
        }
      }

      return false;
    } catch (e) {
      throw Exception('Failed to check category name: $e');
    }
  }

  // Search categories by name
  Future<List<CategoryModel>> searchCategories(String searchTerm) async {
    try {
      final query = await _firestore
          .collection(_categoriesCollection)
          .where('name', isGreaterThanOrEqualTo: searchTerm)
          .where('name', isLessThanOrEqualTo: '$searchTerm\uf8ff')
          .orderBy('name')
          .get();

      return query.docs
          .map((doc) => CategoryModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to search categories: $e');
    }
  }

  // Get category statistics
  Future<Map<String, int>> getCategoryStatistics() async {
    try {
      final allCategories = await getAllCategories();
      final activeCategories = allCategories.where((c) => c.isActive).length;
      final inactiveCategories = allCategories.where((c) => !c.isActive).length;
      final parentCategories = allCategories
          .where((c) => c.parentCategory == null)
          .length;
      final subcategories = allCategories
          .where((c) => c.parentCategory != null)
          .length;

      return {
        'total': allCategories.length,
        'active': activeCategories,
        'inactive': inactiveCategories,
        'parents': parentCategories,
        'subcategories': subcategories,
      };
    } catch (e) {
      throw Exception('Failed to get category statistics: $e');
    }
  }

  // Stream categories for real-time updates
  Stream<List<CategoryModel>> streamCategories() {
    return _firestore
        .collection(_categoriesCollection)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (query) => query.docs
              .map((doc) => CategoryModel.fromJson(doc.data()))
              .toList(),
        );
  }

  // Stream active categories
  Stream<List<CategoryModel>> streamActiveCategories() {
    return _firestore
        .collection(_categoriesCollection)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (query) => query.docs
              .map((doc) => CategoryModel.fromJson(doc.data()))
              .toList(),
        );
  }

  // Get products count for a category
  Future<int> getProductsCountInCategory(String categoryId) async {
    try {
      final query = await _firestore
          .collection(_productsCollection)
          .where('categoryId', isEqualTo: categoryId)
          .get();

      return query.docs.length;
    } catch (e) {
      throw Exception('Failed to get products count: $e');
    }
  }
}
