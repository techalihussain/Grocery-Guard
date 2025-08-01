import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../models/sale_purchase_item_model.dart';
import '../models/user_model.dart';
import '../utils/unit_converter.dart';
import 'payment_repository.dart';

class SalesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PaymentRepository _paymentRepository = PaymentRepository();

  // Stock validation - must run first before any sale
  Future<bool> validateStockAvailability(List<ItemModel> items) async {
    try {
      for (var item in items) {
        final productDoc = await _firestore
            .collection('products')
            .doc(item.productId)
            .get();

        if (!productDoc.exists) {
          return false; // Product not found
        }

        final productData = productDoc.data()!;
        final currentStock = (productData['currentStock'] as num).toDouble();
        final productUnit = productData['unit'] as String;
        
        // Convert item quantity to product's base unit for comparison
        final quantityInBaseUnit = UnitConverter.convertToBaseUnit(item.quantity, item.unit);
        
        if (currentStock < quantityInBaseUnit) {
          return false; // Insufficient stock
        }
      }
      return true;
    } catch (e) {
      throw Exception('Error validating stock: $e');
    }
  }

  // Get all active products
  Future<List<ProductModel>> getActiveProducts() async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('isActive', isEqualTo: true)
          .get();

      final products = snapshot.docs
          .map((doc) => ProductModel.fromJson(doc.data()))
          .toList();

      // Sort by name in memory to avoid Firestore index requirement
      products.sort((a, b) => a.name.compareTo(b.name));

      return products;
    } catch (e) {
      throw Exception('Error getting products: $e');
    }
  }

  // Get product by barcode
  Future<ProductModel?> getProductByBarcode(String barcode) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('barcode', isEqualTo: barcode)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ProductModel.fromJson(snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      throw Exception('Error getting product by barcode: $e');
    }
  }

  // Check if invoice number is unique
  Future<bool> isInvoiceNumberUnique(
    String invoiceNumber, {
    String? excludeSaleId,
  }) async {
    try {
      // Query for any sale with this invoice number
      final query = _firestore
          .collection('sales')
          .where('invoiceNo', isEqualTo: invoiceNumber);

      final snapshot = await query.get();

      // If no documents found, the invoice number is unique
      if (snapshot.docs.isEmpty) {
        return true;
      }

      // If we're editing a sale, we need to exclude the current sale from the check
      if (excludeSaleId != null) {
        // Check if the only document found is the one we're editing
        if (snapshot.docs.length == 1 &&
            snapshot.docs.first.id == excludeSaleId) {
          return true;
        }
      }

      // Invoice number is not unique
      return false;
    } catch (e) {
      throw Exception('Error checking invoice number uniqueness: $e');
    }
  }

  // Generate next invoice number
  Future<String> generateInvoiceNumber() async {
    try {
      // Get the latest sale to find the highest invoice number
      final snapshot = await _firestore
          .collection('sales')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        // First invoice
        return 'INV-0001';
      }

      final latestSale = SaleModel.fromJson(snapshot.docs.first.data());
      final latestInvoiceNo = latestSale.invoiceNo;

      // Extract number from invoice (e.g., "INV-0001" -> "0001")
      if (latestInvoiceNo.startsWith('INV-')) {
        final numberPart = latestInvoiceNo.substring(4);
        final currentNumber = int.tryParse(numberPart) ?? 0;
        final nextNumber = currentNumber + 1;

        // Format with leading zeros (4 digits)
        return 'INV-${nextNumber.toString().padLeft(4, '0')}';
      } else {
        // Fallback if format is different
        return 'INV-0001';
      }
    } catch (e) {
      // Fallback on error
      return 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    }
  }

  // Get all customers (users with role 'customer')
  Future<List<UserModel>> getCustomers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'customer')
          .where('isActive', isEqualTo: true)
          .get();

      final customers = snapshot.docs
          .map((doc) => UserModel.fromJson(doc.data()))
          .toList();

      // Sort by name in memory to avoid Firestore index requirement
      customers.sort((a, b) => a.name.compareTo(b.name));

      return customers;
    } catch (e) {
      throw Exception('Error getting customers: $e');
    }
  }

  // Create draft sale (no stock or payment impact)
  Future<void> createDraftSale(SaleModel sale, List<ItemModel> items) async {
    try {
      final batch = _firestore.batch();

      // Add sale document
      final saleRef = _firestore.collection('sales').doc(sale.id);
      batch.set(saleRef, sale.toJson());

      // Add sale items to subCollection with correct saleId
      for (var item in items) {
        final itemRef = saleRef.collection('saleItems').doc();
        final itemWithSaleId = item.copyWith(referenceId: sale.id);
        batch.set(itemRef, itemWithSaleId.toJson());
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Error creating draft sale: $e');
    }
  }

  // Complete sale - converts draft to completed (triggers stock/payment updates)
  Future<void> completeSale(String saleId) async {
    try {
      final saleDoc = await _firestore.collection('sales').doc(saleId).get();
      if (!saleDoc.exists) {
        throw Exception('Sale not found');
      }

      final sale = SaleModel.fromJson(saleDoc.data()!);
      if (sale.status == 'completed') {
        throw Exception('Sale is already completed');
      }

      // Get sale items
      final itemsSnapshot = await _firestore
          .collection('sales')
          .doc(saleId)
          .collection('saleItems')
          .get();

      final items = itemsSnapshot.docs
          .map((doc) => ItemModel.fromJson(doc.data()))
          .toList();

      // Validate stock again before completing
      final stockAvailable = await validateStockAvailability(items);
      if (!stockAvailable) {
        throw Exception('Insufficient stock to complete sale');
      }

      if (sale.isCredit) {
        await _completeCreditSale(sale, items);
      } else {
        await _completeCashSale(sale, items);
      }
    } catch (e) {
      throw Exception('Error completing sale: $e');
    }
  }

  // Private method: Complete credit sale (sale + payment record + stock update)
  Future<void> _completeCreditSale(
    SaleModel sale,
    List<ItemModel> items,
  ) async {
    final batch = _firestore.batch();

    // Update stock for each item in products collection
    for (var item in items) {
      final productRef = _firestore.collection('products').doc(item.productId);
      final productDoc = await productRef.get();

      if (productDoc.exists) {
        final currentStock = (productDoc.data()!['currentStock'] as num).toDouble();
        // Convert item quantity to product's base unit before updating stock
        final quantityInBaseUnit = UnitConverter.convertToBaseUnit(item.quantity, item.unit);
        final newStock = currentStock - quantityInBaseUnit;

        batch.update(productRef, {'currentStock': newStock});
      }
    }

    // First record the payment to avoid double-counting
    // This is important: we record the payment BEFORE marking the sale as completed
    // to avoid the sale being counted twice
    await _paymentRepository.recordCreditSale(sale.customerId, sale);
    
    // Now update sale status to completed
    final saleRef = _firestore.collection('sales').doc(sale.id);
    batch.update(saleRef, {'status': 'completed'});

    // Commit the batch to update sale status and stock
    await batch.commit();
  }

  // Private method: Complete cash sale (sale + stock update only)
  Future<void> _completeCashSale(SaleModel sale, List<ItemModel> items) async {
    final batch = _firestore.batch();

    // Update sale status to completed
    final saleRef = _firestore.collection('sales').doc(sale.id);
    batch.update(saleRef, {'status': 'completed'});

    // Update stock for each item in products collection
    for (var item in items) {
      final productRef = _firestore.collection('products').doc(item.productId);
      final productDoc = await productRef.get();

      if (productDoc.exists) {
        final currentStock = (productDoc.data()!['currentStock'] as num).toDouble();
        // Convert item quantity to product's base unit before updating stock
        final quantityInBaseUnit = UnitConverter.convertToBaseUnit(item.quantity, item.unit);
        final newStock = currentStock - quantityInBaseUnit;

        batch.update(productRef, {'currentStock': newStock});
      }
    }

    await batch.commit();
    
    // Cash sales don't affect the payment collection
    // No need to record anything in payment collection
  }

  // Get single sale
  Future<SaleModel?> getSale(String saleId) async {
    try {
      final doc = await _firestore.collection('sales').doc(saleId).get();
      if (doc.exists) {
        return SaleModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Error getting sale: $e');
    }
  }

  // Get draft sales for editing
  Future<List<SaleModel>> getDraftSales() async {
    try {
      final snapshot = await _firestore
          .collection('sales')
          .where('status', isEqualTo: 'drafted')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => SaleModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error getting draft sales: $e');
    }
  }

  // Get all sales (completed, drafted, returns)
  Future<List<SaleModel>> getAllSales() async {
    try {
      final snapshot = await _firestore
          .collection('sales')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => SaleModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error getting all sales: $e');
    }
  }

  // Process return with refund option (cash or credit sale)
  Future<void> processReturn(
    String originalSaleId,
    List<ItemModel> returnItems, {
    String refundMethod = 'credit_adjustment', // 'credit_adjustment' or 'cash_refund'
  }) async {
    try {
      final originalSaleDoc = await _firestore
          .collection('sales')
          .doc(originalSaleId)
          .get();
      if (!originalSaleDoc.exists) {
        throw Exception('Original sale not found');
      }

      final originalSale = SaleModel.fromJson(originalSaleDoc.data()!);
      if (originalSale.status != 'completed') {
        throw Exception('Can only return completed sales');
      }

      // Calculate return amount
      double returnAmount = 0.0;
      for (var item in returnItems) {
        returnAmount += item.totalPrice;
      }

      final batch = _firestore.batch();

      // Create return sale record
      final returnSale = originalSale.copyWith(
        id: _firestore.collection('sales').doc().id,
        isReturn: true,
        originalId: originalSaleId,
        totalAmount: -returnAmount, // Negative amount for return
        createdAt: DateTime.now(),
      );

      final returnSaleRef = _firestore.collection('sales').doc(returnSale.id);
      batch.set(returnSaleRef, returnSale.toJson());

      // Add return items
      for (var item in returnItems) {
        final returnItemRef = returnSaleRef.collection('saleItems').doc();
        batch.set(
          returnItemRef,
          item.copyWith(referenceId: returnSale.id).toJson(),
        );
      }

      // Update stock (increase for returned items) in products collection
      for (var item in returnItems) {
        final productRef = _firestore
            .collection('products')
            .doc(item.productId);
        final productDoc = await productRef.get();

        if (productDoc.exists) {
          final currentStock = (productDoc.data()!['currentStock'] as num).toDouble();
          final newStock = currentStock + item.quantity; // Add back to stock

          batch.update(productRef, {'currentStock': newStock});
        }
      }

      // Commit the batch to create return sale and update stock
      await batch.commit();

      // Handle payment records for the return using PaymentRepository
      if (originalSale.isCredit) {
        await _paymentRepository.processReturn(
          originalSale.customerId,
          originalSale,
          returnSale,
          refundMethod: refundMethod,
        );
      }
      // For cash sales, no payment record is needed - just the return sale record
    } catch (e) {
      throw Exception('Error processing return: $e');
    }
  }

  // Delete draft sale
  Future<void> deleteDraftSale(String saleId) async {
    try {
      final saleDoc = await _firestore.collection('sales').doc(saleId).get();
      if (!saleDoc.exists) {
        throw Exception('Sale not found');
      }

      final sale = SaleModel.fromJson(saleDoc.data()!);
      if (sale.status != 'drafted') {
        throw Exception('Can only delete draft sales');
      }

      final batch = _firestore.batch();

      // Delete all sale items first
      final itemsSnapshot = await _firestore
          .collection('sales')
          .doc(saleId)
          .collection('saleItems')
          .get();

      for (var itemDoc in itemsSnapshot.docs) {
        batch.delete(itemDoc.reference);
      }

      // Delete the sale document
      batch.delete(_firestore.collection('sales').doc(saleId));

      await batch.commit();
    } catch (e) {
      throw Exception('Error deleting draft sale: $e');
    }
  }

  // Get sale items for a specific sale
  Future<List<ItemModel>> getSaleItems(String saleId) async {
    try {
      final snapshot = await _firestore
          .collection('sales')
          .doc(saleId)
          .collection('saleItems')
          .get();

      return snapshot.docs
          .map((doc) => ItemModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error getting sale items: $e');
    }
  }

  // Get returned items for a specific sale
  Future<List<ItemModel>> getReturnedItems(String saleId) async {
    try {
      // Get all returns for this sale
      final returnsSnapshot = await _firestore
          .collection('sales')
          .where('originalId', isEqualTo: saleId)
          .where('isReturn', isEqualTo: true)
          .get();

      List<ItemModel> returnedItems = [];

      // For each return, get its items
      for (var returnDoc in returnsSnapshot.docs) {
        final returnItemsSnapshot = await _firestore
            .collection('sales')
            .doc(returnDoc.id)
            .collection('saleItems')
            .get();

        final items = returnItemsSnapshot.docs
            .map((doc) => ItemModel.fromJson(doc.data()))
            .toList();

        returnedItems.addAll(items);
      }

      return returnedItems;
    } catch (e) {
      throw Exception('Error getting returned items: $e');
    }
  }

  // Get returns for a specific sale
  Future<List<SaleModel>> getReturnsForSale(String saleId) async {
    try {
      final snapshot = await _firestore
          .collection('sales')
          .where('originalId', isEqualTo: saleId)
          .where('isReturn', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => SaleModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error getting returns for sale: $e');
    }
  }

  // Get available items for return (items that haven't been fully returned)
  Future<List<ItemModel>> getAvailableItemsForReturn(String saleId) async {
    try {
      // Get original sale items
      final originalItems = await getSaleItems(saleId);

      // Get all returns for this sale
      final returnsSnapshot = await _firestore
          .collection('sales')
          .where('originalId', isEqualTo: saleId)
          .where('isReturn', isEqualTo: true)
          .get();

      if (returnsSnapshot.docs.isEmpty) {
        // No returns yet, all items are available
        return originalItems;
      }

      // Calculate returned quantities for each product
      Map<String, double> returnedQuantities = {};

      for (var returnDoc in returnsSnapshot.docs) {
        final returnItemsSnapshot = await _firestore
            .collection('sales')
            .doc(returnDoc.id)
            .collection('saleItems')
            .get();

        for (var returnItemDoc in returnItemsSnapshot.docs) {
          final returnItem = ItemModel.fromJson(returnItemDoc.data());
          returnedQuantities[returnItem.productId] =
              (returnedQuantities[returnItem.productId] ?? 0) +
              returnItem.quantity;
        }
      }

      // Filter original items to only include available quantities
      List<ItemModel> availableItems = [];

      for (var originalItem in originalItems) {
        final returnedQty = returnedQuantities[originalItem.productId] ?? 0;
        final availableQty = originalItem.quantity - returnedQty;

        if (availableQty > 0) {
          // Create a new item with available quantity
          availableItems.add(
            originalItem.copyWith(
              quantity: availableQty,
              totalPrice: originalItem.unitPrice * availableQty,
            ),
          );
        }
      }

      return availableItems;
    } catch (e) {
      throw Exception('Error getting available items for return: $e');
    }
  }

  // Get refund availability information for a sale
  Future<Map<String, double>> getRefundAvailability(
    String userId,
    String saleId,
  ) async {
    try {
      return await _paymentRepository.getRefundAvailability(userId, saleId);
    } catch (e) {
      throw Exception('Error getting refund availability: $e');
    }
  }
}