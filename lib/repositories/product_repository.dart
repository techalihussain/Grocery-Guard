import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_model.dart';
import '../models/stock_model.dart';

class ProductRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'products';

  // CRUD Operations

  /// Create a new product
  Future<String> createProduct(ProductModel product) async {
    try {
      // Create a document reference to get the ID first
      final docRef = _firestore.collection(_collection).doc();

      // Update the product with the generated document ID
      final productWithId = product.copyWith(id: docRef.id);

      // Set the document with the product data including the ID
      await docRef.set(productWithId.toMap());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create product: $e');
    }
  }

  /// Get product by ID
  Future<ProductModel?> getProductById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists && doc.data() != null) {
        return ProductModel.fromJson({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get product: $e');
    }
  }

  /// Update product
  Future<void> updateProduct(String id, ProductModel product) async {
    try {
      final updatedProduct = product.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection(_collection)
          .doc(id)
          .update(updatedProduct.toMap());
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  /// Delete product (permanent removal from database)
  Future<void> deleteProduct(String id) async {
    try {
      // Use a batch to ensure all operations succeed or fail together
      final batch = _firestore.batch();
      final productDocRef = _firestore.collection(_collection).doc(id);

      // First, get all documents in the stockLedger subCollection
      final stockLedgerSnapshot = await productDocRef
          .collection('stockLedger')
          .get();

      // Add all stockLedger documents to the batch for deletion
      for (final doc in stockLedgerSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Add the main product document to the batch for deletion
      batch.delete(productDocRef);

      // Execute all deletions in a single batch
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }
  // Listing and Filtering Operations

  /// Get all active products
  Future<List<ProductModel>> getAllProducts() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      return querySnapshot.docs
          .map((doc) => ProductModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get products: $e');
    }
  }

  /// Get products with pagination
  Future<List<ProductModel>> getProductsPaginated({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map(
            (doc) => ProductModel.fromJson({
              ...doc.data() as Map<String, dynamic>,
              'id': doc.id,
            }),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get paginated products: $e');
    }
  }

  /// Search products by name
  Future<List<ProductModel>> searchProductsByName(String searchTerm) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .where('name', isGreaterThanOrEqualTo: searchTerm)
          .where('name', isLessThanOrEqualTo: '$searchTerm\uf8ff')
          .get();

      return querySnapshot.docs
          .map((doc) => ProductModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to search products: $e');
    }
  }

  /// Get products by category
  Future<List<ProductModel>> getProductsByCategory(String categoryId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .where('categoryId', isEqualTo: categoryId)
          .orderBy('name')
          .get();

      return querySnapshot.docs
          .map((doc) => ProductModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get products by category: $e');
    }
  }

  /// Get products by vendor
  Future<List<ProductModel>> getProductsByVendor(String vendorId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .where('vendorId', isEqualTo: vendorId)
          .orderBy('name')
          .get();

      return querySnapshot.docs
          .map((doc) => ProductModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get products by vendor: $e');
    }
  }

  /// Get products by brand
  Future<List<ProductModel>> getProductsByBrand(String brand) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .where('brand', isEqualTo: brand)
          .orderBy('name')
          .get();

      return querySnapshot.docs
          .map((doc) => ProductModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get products by brand: $e');
    }
  }

  // Stock Management Operations

  /// Manual stock adjustment with ledger tracking (for admin adjustments only)
  Future<void> manualStockAdjustment({
    required String productId,
    required int change,
    required String createdBy,
    bool isAddition = true,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection(_collection).doc(productId);
        final doc = await transaction.get(docRef);

        if (!doc.exists) {
          throw Exception('Product not found');
        }

        final currentStock = (doc.data()!['currentStock'] as num).toDouble();
        final actualChange = isAddition ? change : -change;
        final newStock = currentStock + actualChange;

        if (newStock < 0) {
          throw Exception('Cannot reduce stock below zero');
        }

        // Auto-set note based on operation type
        final note = isAddition ? 'Founded' : 'Damaged';

        // Update product stock
        transaction.update(docRef, {
          'currentStock': newStock,
          'updatedAt': DateTime.now(),
        });

        // Record in stock ledger
        final stockLedgerRef = docRef.collection('stockLedger').doc();
        final stockEntry = StockModel(
          change: actualChange,
          reason: note,
          createdAt: DateTime.now(),
          resultingStock: newStock,
          createdBy: createdBy,
        );
        transaction.set(stockLedgerRef, stockEntry.toMap());
      });
    } catch (e) {
      throw Exception('Failed to perform manual stock adjustment: $e');
    }
  }

  /// Get stock ledger for a product (manual adjustments only)
  Future<List<StockModel>> getStockLedger(
    String productId, {
    int? limit,
  }) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .doc(productId)
          .collection('stockLedger')
          .orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => StockModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get stock ledger: $e');
    }
  }

  /// Update product stock (without ledger tracking - for sales/purchases)
  Future<void> updateStock(String productId, double newStock) async {
    try {
      await _firestore.collection(_collection).doc(productId).update({
        'currentStock': newStock,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to update stock: $e');
    }
  }

  /// Add stock to existing inventory
  Future<void> addStock(String productId, double quantity) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection(_collection).doc(productId);
        final doc = await transaction.get(docRef);

        if (!doc.exists) {
          throw Exception('Product not found');
        }

        final currentStock = (doc.data()!['currentStock'] as num).toDouble();
        final newStock = currentStock + quantity;

        transaction.update(docRef, {
          'currentStock': newStock,
          'updatedAt': DateTime.now(),
        });
      });
    } catch (e) {
      throw Exception('Failed to add stock: $e');
    }
  }

  /// Reduce stock (for sales)
  Future<bool> reduceStock(String productId, double quantity) async {
    try {
      bool success = false;
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection(_collection).doc(productId);
        final doc = await transaction.get(docRef);

        if (!doc.exists) {
          throw Exception('Product not found');
        }

        final currentStock = (doc.data()!['currentStock'] as num).toDouble();

        if (currentStock >= quantity) {
          final newStock = currentStock - quantity;
          transaction.update(docRef, {
            'currentStock': newStock,
            'updatedAt': DateTime.now(),
          });
          success = true;
        }
      });
      return success;
    } catch (e) {
      throw Exception('Failed to reduce stock: $e');
    }
  }

  /// Get products with low stock
  Future<List<ProductModel>> getLowStockProducts() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      final products = querySnapshot.docs
          .map((doc) => ProductModel.fromJson({...doc.data(), 'id': doc.id}))
          .where((product) => product.currentStock <= product.minimumStockLevel)
          .toList();

      return products;
    } catch (e) {
      throw Exception('Failed to get low stock products: $e');
    }
  }

  /// Get out of stock products
  Future<List<ProductModel>> getOutOfStockProducts() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .where('currentStock', isEqualTo: 0)
          .get();

      return querySnapshot.docs
          .map((doc) => ProductModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get out of stock products: $e');
    }
  }

  // Business Analytics Operations

  /// Get products by price range
  Future<List<ProductModel>> getProductsByPriceRange({
    required double minPrice,
    required double maxPrice,
    bool useSalePrice = true,
  }) async {
    try {
      final priceField = useSalePrice ? 'salePrice' : 'purchasePrice';
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .where(priceField, isGreaterThanOrEqualTo: minPrice)
          .where(priceField, isLessThanOrEqualTo: maxPrice)
          .orderBy(priceField)
          .get();

      return querySnapshot.docs
          .map((doc) => ProductModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get products by price range: $e');
    }
  }

  /// Get most profitable products (highest profit margin)
  Future<List<ProductModel>> getMostProfitableProducts({int limit = 10}) async {
    try {
      final products = await getAllProducts();

      products.sort((a, b) {
        final profitA = a.salePrice - a.purchasePrice;
        final profitB = b.salePrice - b.purchasePrice;
        return profitB.compareTo(profitA);
      });

      return products.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get most profitable products: $e');
    }
  }

  /// Get total inventory value
  Future<double> getTotalInventoryValue({bool useSalePrice = true}) async {
    try {
      final products = await getAllProducts();
      double totalValue = 0;

      for (final product in products) {
        final price = useSalePrice ? product.salePrice : product.purchasePrice;
        totalValue += price * product.currentStock;
      }

      return totalValue;
    } catch (e) {
      throw Exception('Failed to calculate total inventory value: $e');
    }
  }

  /// Get product count by category
  Future<Map<String, int>> getProductCountByCategory() async {
    try {
      final products = await getAllProducts();
      final Map<String, int> categoryCount = {};

      for (final product in products) {
        categoryCount[product.categoryId] =
            (categoryCount[product.categoryId] ?? 0) + 1;
      }

      return categoryCount;
    } catch (e) {
      throw Exception('Failed to get product count by category: $e');
    }
  }

  // Barcode Operations

  /// Check if barcode is unique (not used by any other product)
  Future<bool> isBarcodeUnique(String barcode, {String? excludeProductId}) async {
    try {
      if (barcode.trim().isEmpty) return true; // Empty barcode is always valid
      
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('barcode', isEqualTo: barcode.trim())
          .get();

      // If no products found with this barcode, it's unique
      if (querySnapshot.docs.isEmpty) return true;

      // If we're updating a product, exclude it from the check
      if (excludeProductId != null) {
        final otherProducts = querySnapshot.docs
            .where((doc) => doc.id != excludeProductId)
            .toList();
        return otherProducts.isEmpty;
      }

      // Barcode already exists
      return false;
    } catch (e) {
      throw Exception('Failed to check barcode uniqueness: $e');
    }
  }

  /// Get product by barcode
  Future<ProductModel?> getProductByBarcode(String barcode) async {
    try {
      if (barcode.trim().isEmpty) return null;
      
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .where('barcode', isEqualTo: barcode.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return ProductModel.fromJson({...doc.data(), 'id': doc.id});
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get product by barcode: $e');
    }
  }

  /// Search products by barcode (for partial matches)
  Future<List<ProductModel>> searchProductsByBarcode(String barcodeQuery) async {
    try {
      if (barcodeQuery.trim().isEmpty) return [];
      
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .where('barcode', isGreaterThanOrEqualTo: barcodeQuery.trim())
          .where('barcode', isLessThanOrEqualTo: '${barcodeQuery.trim()}\uf8ff')
          .get();

      return querySnapshot.docs
          .map((doc) => ProductModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to search products by barcode: $e');
    }
  }

  /// Check if product name already exists in category (case-insensitive)
  Future<bool> isProductNameExists(String name, String categoryId, {String? excludeProductId}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('categoryId', isEqualTo: categoryId)
          .get();

      final normalizedName = name.toLowerCase().trim();

      for (var doc in querySnapshot.docs) {
        final product = ProductModel.fromJson({...doc.data(), 'id': doc.id});
        
        // Skip the product being updated
        if (excludeProductId != null && product.id == excludeProductId) {
          continue;
        }
        
        // Check for exact case-insensitive match
        if (product.name.toLowerCase().trim() == normalizedName) {
          return true;
        }
      }

      return false;
    } catch (e) {
      throw Exception('Failed to check product name: $e');
    }
  }

  /// Check for potential duplicate products by name and category
  Future<List<ProductModel>> findSimilarProducts(String name, String categoryId, {String? excludeProductId}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .where('categoryId', isEqualTo: categoryId)
          .get();

      final products = querySnapshot.docs
          .map((doc) => ProductModel.fromJson({...doc.data(), 'id': doc.id}))
          .where((product) {
            // Exclude the current product if updating
            if (excludeProductId != null && product.id == excludeProductId) {
              return false;
            }
            
            // Check for similar names (case-insensitive)
            final productName = product.name.toLowerCase().trim();
            final searchName = name.toLowerCase().trim();
            
            return productName == searchName || 
                   productName.contains(searchName) || 
                   searchName.contains(productName);
          })
          .toList();

      return products;
    } catch (e) {
      throw Exception('Failed to find similar products: $e');
    }
  }

  // Real-time Operations

  /// Stream all products (both active and inactive)
  Stream<List<ProductModel>> streamAllProducts() {
    return _firestore
        .collection(_collection)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ProductModel.fromJson({...doc.data(), 'id': doc.id}),
              )
              .toList(),
        );
  }

  /// Stream only active products
  Stream<List<ProductModel>> streamProducts() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ProductModel.fromJson({...doc.data(), 'id': doc.id}),
              )
              .toList(),
        );
  }

  /// Stream products by category
  Stream<List<ProductModel>> streamProductsByCategory(String categoryId) {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('categoryId', isEqualTo: categoryId)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ProductModel.fromJson({...doc.data(), 'id': doc.id}),
              )
              .toList(),
        );
  }

  /// Stream low stock products
  Stream<List<ProductModel>> streamLowStockProducts() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ProductModel.fromJson({...doc.data(), 'id': doc.id}),
              )
              .where(
                (product) => product.currentStock <= product.minimumStockLevel,
              )
              .toList(),
        );
  }

  // Batch Operations

  /// Bulk update products
  Future<void> bulkUpdateProducts(List<Map<String, dynamic>> updates) async {
    try {
      final batch = _firestore.batch();

      for (final update in updates) {
        final docRef = _firestore.collection(_collection).doc(update['id']);
        batch.update(docRef, {...update, 'updatedAt': DateTime.now()});
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to bulk update products: $e');
    }
  }

  /// Bulk create products
  Future<List<String>> bulkCreateProducts(List<ProductModel> products) async {
    try {
      final batch = _firestore.batch();
      final List<String> ids = [];

      for (final product in products) {
        final docRef = _firestore.collection(_collection).doc();
        final productWithId = product.copyWith(id: docRef.id);
        batch.set(docRef, productWithId.toMap());
        ids.add(docRef.id);
      }

      await batch.commit();
      return ids;
    } catch (e) {
      throw Exception('Failed to bulk create products: $e');
    }
  }

  /// Update minimum stock levels for multiple products
  Future<void> updateMinimumStockLevels(
    Map<String, double> productStockLevels,
  ) async {
    try {
      final batch = _firestore.batch();

      productStockLevels.forEach((productId, minLevel) {
        final docRef = _firestore.collection(_collection).doc(productId);
        batch.update(docRef, {
          'minimumStockLevel': minLevel,
          'updatedAt': DateTime.now(),
        });
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to update minimum stock levels: $e');
    }
  }
}
