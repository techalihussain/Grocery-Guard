import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_model.dart';
import '../models/purchase_model.dart';
import '../models/sale_purchase_item_model.dart';
import '../models/user_model.dart';
import '../utils/unit_converter.dart';
import 'payment_repository.dart';

class PurchaseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PaymentRepository _paymentRepository = PaymentRepository();

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
    String? excludePurchaseId,
  }) async {
    try {
      // Query for any purchase with this invoice number
      final query = _firestore
          .collection('purchases')
          .where('invoiceNo', isEqualTo: invoiceNumber);

      final snapshot = await query.get();

      // If no documents found, the invoice number is unique
      if (snapshot.docs.isEmpty) {
        return true;
      }

      // If we're editing a purchase, we need to exclude the current purchase from the check
      if (excludePurchaseId != null) {
        // Check if the only document found is the one we're editing
        if (snapshot.docs.length == 1 &&
            snapshot.docs.first.id == excludePurchaseId) {
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
      // Get the latest purchase to find the highest invoice number
      final snapshot = await _firestore
          .collection('purchases')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        // First invoice
        return 'PUR-0001';
      }

      final latestPurchase = PurchaseModel.fromJson(snapshot.docs.first.data());
      final latestInvoiceNo = latestPurchase.invoiceNo;

      // Extract number from invoice (e.g., "PUR-0001" -> "0001")
      if (latestInvoiceNo.startsWith('PUR-')) {
        final numberPart = latestInvoiceNo.substring(4);
        final currentNumber = int.tryParse(numberPart) ?? 0;
        final nextNumber = currentNumber + 1;

        // Format with leading zeros (4 digits)
        return 'PUR-${nextNumber.toString().padLeft(4, '0')}';
      } else {
        // Fallback if format is different
        return 'PUR-0001';
      }
    } catch (e) {
      // Fallback on error
      return 'PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    }
  }

  // Get all vendors (users with role 'vendor')
  Future<List<UserModel>> getVendors() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'vendor')
          .where('isActive', isEqualTo: true)
          .get();

      final vendors = snapshot.docs
          .map((doc) => UserModel.fromJson(doc.data()))
          .toList();

      // Sort by name in memory to avoid Firestore index requirement
      vendors.sort((a, b) => a.name.compareTo(b.name));

      return vendors;
    } catch (e) {
      throw Exception('Error getting vendors: $e');
    }
  }

  // CreateDraft purchase (no stock or payment impact)
  Future<void> createDraftPurchase(
    PurchaseModel purchase,
    List<ItemModel> items,
  ) async {
    try {
      final batch = _firestore.batch();

      // Add purchase document
      final purchaseRef = _firestore.collection('purchases').doc(purchase.id);
      batch.set(purchaseRef, purchase.toJson());

      // Add purchase items to subCollection with correct purchaseId
      for (var item in items) {
        final itemRef = purchaseRef.collection('purchaseItems').doc();
        final itemWithPurchaseId = item.copyWith(referenceId: purchase.id);
        batch.set(itemRef, itemWithPurchaseId.toJson());
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Error creating draft purchase: $e');
    }
  }

  // Complete purchase - converts draft to completed (triggers stock/payment updates)
  Future<void> completePurchase(String purchaseId) async {
    try {
      final purchaseDoc = await _firestore
          .collection('purchases')
          .doc(purchaseId)
          .get();
      if (!purchaseDoc.exists) {
        throw Exception('Purchase not found');
      }

      final purchase = PurchaseModel.fromJson(purchaseDoc.data()!);
      if (purchase.status == 'completed') {
        throw Exception('Purchase is already completed');
      }

      // Get purchase items
      final itemsSnapshot = await _firestore
          .collection('purchases')
          .doc(purchaseId)
          .collection('purchaseItems')
          .get();

      final items = itemsSnapshot.docs
          .map((doc) => ItemModel.fromJson(doc.data()))
          .toList();

      if (purchase.isCredit) {
        await _completeCreditPurchase(purchase, items);
      } else {
        await _completeCashPurchase(purchase, items);
      }
    } catch (e) {
      throw Exception('Error completing purchase: $e');
    }
  }

  // Private method: Complete credit purchase (purchase + payment record + stock update)
  Future<void> _completeCreditPurchase(
    PurchaseModel purchase,
    List<ItemModel> items,
  ) async {
    final batch = _firestore.batch();

    // Update stock for each item in products collection (increase stock for purchases)
    for (var item in items) {
      final productRef = _firestore.collection('products').doc(item.productId);
      final productDoc = await productRef.get();

      if (productDoc.exists) {
        final currentStock = (productDoc.data()!['currentStock'] as num).toDouble();
        // Convert item quantity to product's base unit before updating stock
        final quantityInBaseUnit = UnitConverter.convertToBaseUnit(item.quantity, item.unit);
        final newStock = currentStock + quantityInBaseUnit; // Add to stock for purchases

        batch.update(productRef, {'currentStock': newStock});
      }
    }

    // First record the payment to avoid double-counting
    await _paymentRepository.recordCreditPurchase(purchase.vendorId, purchase);

    // Now update purchase status to completed
    final purchaseRef = _firestore.collection('purchases').doc(purchase.id);
    batch.update(purchaseRef, {'status': 'completed'});

    // Commit the batch to update purchase status and stock
    await batch.commit();
  }

  // Private method: Complete cash purchase (purchase + stock update only)
  Future<void> _completeCashPurchase(
    PurchaseModel purchase,
    List<ItemModel> items,
  ) async {
    final batch = _firestore.batch();

    // Update purchase status to completed
    final purchaseRef = _firestore.collection('purchases').doc(purchase.id);
    batch.update(purchaseRef, {'status': 'completed'});

    // Update stock for each item in products collection (increase stock for purchases)
    for (var item in items) {
      final productRef = _firestore.collection('products').doc(item.productId);
      final productDoc = await productRef.get();

      if (productDoc.exists) {
        final currentStock = (productDoc.data()!['currentStock'] as num).toDouble();
        // Convert item quantity to product's base unit before updating stock
        final quantityInBaseUnit = UnitConverter.convertToBaseUnit(item.quantity, item.unit);
        final newStock = currentStock + quantityInBaseUnit; // Add to stock for purchases

        batch.update(productRef, {'currentStock': newStock});
      }
    }

    await batch.commit();

    // Cash purchases don't affect the payment collection
    // No need to record anything in payment collection
  }

  // Get single purchase
  Future<PurchaseModel?> getPurchase(String purchaseId) async {
    try {
      final doc = await _firestore
          .collection('purchases')
          .doc(purchaseId)
          .get();
      if (doc.exists) {
        return PurchaseModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Error getting purchase: $e');
    }
  }

  // Get draft purchases for editing
  Future<List<PurchaseModel>> getDraftPurchases() async {
    try {
      final snapshot = await _firestore
          .collection('purchases')
          .where('status', isEqualTo: 'drafted')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PurchaseModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error getting draft purchases: $e');
    }
  }

  // Get all purchases (completed, drafted, returns)
  Future<List<PurchaseModel>> getAllPurchases() async {
    try {
      final snapshot = await _firestore
          .collection('purchases')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PurchaseModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error getting all purchases: $e');
    }
  } // Process return with refund option (cash or credit purchase)

  Future<void> processReturn(
    String originalPurchaseId,
    List<ItemModel> returnItems, {
    String refundMethod =
        'credit_adjustment', // 'credit_adjustment' or 'cash_refund'
  }) async {
    try {
      final originalPurchaseDoc = await _firestore
          .collection('purchases')
          .doc(originalPurchaseId)
          .get();
      if (!originalPurchaseDoc.exists) {
        throw Exception('Original purchase not found');
      }

      final originalPurchase = PurchaseModel.fromJson(
        originalPurchaseDoc.data()!,
      );
      if (originalPurchase.status != 'completed') {
        throw Exception('Can only return completed purchases');
      }

      // Calculate return amount
      double returnAmount = 0.0;
      for (var item in returnItems) {
        returnAmount += item.totalPrice;
      }

      final batch = _firestore.batch();

      // Create return purchase record
      final returnPurchase = PurchaseModel(
        id: _firestore.collection('purchases').doc().id,
        totalAmount: -returnAmount, // Negative amount for return
        isReturn: true,
        isCredit: originalPurchase.isCredit,
        invoiceNo: originalPurchase.invoiceNo,
        createdBy: originalPurchase.createdBy,
        createdAt: DateTime.now(),
        paymentMethod: originalPurchase.paymentMethod,
        vendorId: originalPurchase.vendorId,
        originalId: originalPurchaseId,
        tax: originalPurchase.tax,
        discount: originalPurchase.discount,
        subtotals: originalPurchase.subtotals,
        status: 'completed', // Returns are immediately completed
      );

      final returnPurchaseRef = _firestore
          .collection('purchases')
          .doc(returnPurchase.id);
      batch.set(returnPurchaseRef, returnPurchase.toJson());

      // Add return items
      for (var item in returnItems) {
        final returnItemRef = returnPurchaseRef
            .collection('purchaseItems')
            .doc();
        batch.set(
          returnItemRef,
          item.copyWith(referenceId: returnPurchase.id).toJson(),
        );
      }

      // Update stock (decrease for returned items) in products collection
      for (var item in returnItems) {
        final productRef = _firestore
            .collection('products')
            .doc(item.productId);
        final productDoc = await productRef.get();

        if (productDoc.exists) {
          final currentStock = (productDoc.data()!['currentStock'] as num).toDouble();
          final newStock =
              currentStock -
              item.quantity; // Remove from stock for purchase returns

          batch.update(productRef, {'currentStock': newStock});
        }
      }

      // Commit the batch to create return purchase and update stock
      await batch.commit();

      // Handle payment records for the return using PaymentRepository
      if (originalPurchase.isCredit) {
        await _paymentRepository.processPurchaseReturn(
          originalPurchase.vendorId,
          originalPurchase,
          returnPurchase,
          refundMethod: refundMethod,
        );
      }
      // For cash purchases, no payment record is needed - just the return purchase record
    } catch (e) {
      throw Exception('Error processing return: $e');
    }
  }

  // Delete draft purchase
  Future<void> deleteDraftPurchase(String purchaseId) async {
    try {
      final purchaseDoc = await _firestore
          .collection('purchases')
          .doc(purchaseId)
          .get();
      if (!purchaseDoc.exists) {
        throw Exception('Purchase not found');
      }

      final purchase = PurchaseModel.fromJson(purchaseDoc.data()!);
      if (purchase.status != 'drafted') {
        throw Exception('Can only delete draft purchases');
      }

      final batch = _firestore.batch();

      // Delete all purchase items first
      final itemsSnapshot = await _firestore
          .collection('purchases')
          .doc(purchaseId)
          .collection('purchaseItems')
          .get();

      for (var itemDoc in itemsSnapshot.docs) {
        batch.delete(itemDoc.reference);
      }

      // Delete the purchase document
      batch.delete(_firestore.collection('purchases').doc(purchaseId));

      await batch.commit();
    } catch (e) {
      throw Exception('Error deleting draft purchase: $e');
    }
  }

  // Get purchase items for a specific purchase
  Future<List<ItemModel>> getPurchaseItems(String purchaseId) async {
    try {
      final snapshot = await _firestore
          .collection('purchases')
          .doc(purchaseId)
          .collection('purchaseItems')
          .get();

      return snapshot.docs
          .map((doc) => ItemModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error getting purchase items: $e');
    }
  }

  // Get returned items for a specific purchase
  Future<List<ItemModel>> getReturnedItems(String purchaseId) async {
    try {
      // Get all returns for this purchase
      final returnsSnapshot = await _firestore
          .collection('purchases')
          .where('originalId', isEqualTo: purchaseId)
          .where('isReturn', isEqualTo: true)
          .get();

      List<ItemModel> returnedItems = [];

      // For each return, get its items
      for (var returnDoc in returnsSnapshot.docs) {
        final returnItemsSnapshot = await _firestore
            .collection('purchases')
            .doc(returnDoc.id)
            .collection('purchaseItems')
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

  // Get returns for a specific purchase
  Future<List<PurchaseModel>> getReturnsForPurchase(String purchaseId) async {
    try {
      final snapshot = await _firestore
          .collection('purchases')
          .where('originalId', isEqualTo: purchaseId)
          .where('isReturn', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => PurchaseModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error getting returns for purchase: $e');
    }
  }

  // Get available items for return (items that haven't been fully returned)
  Future<List<ItemModel>> getAvailableItemsForReturn(String purchaseId) async {
    try {
      // Get original purchase items
      final originalItems = await getPurchaseItems(purchaseId);

      // Get all returns for this purchase
      final returnsSnapshot = await _firestore
          .collection('purchases')
          .where('originalId', isEqualTo: purchaseId)
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
            .collection('purchases')
            .doc(returnDoc.id)
            .collection('purchaseItems')
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

  // Get refund availability information for a purchase
  Future<Map<String, double>> getRefundAvailability(
    String userId,
    String purchaseId,
  ) async {
    try {
      return await _paymentRepository.getPurchaseRefundAvailability(
        userId,
        purchaseId,
      );
    } catch (e) {
      throw Exception('Error getting refund availability: $e');
    }
  }
}
