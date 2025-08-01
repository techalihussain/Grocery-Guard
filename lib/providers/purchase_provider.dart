import 'package:flutter/foundation.dart';

import '../models/product_model.dart';
import '../models/purchase_model.dart';
import '../models/sale_purchase_item_model.dart';
import '../models/user_model.dart';
import '../repositories/purchase_repository.dart';
import '../services/connectivity_service.dart';
import 'payment_provider.dart';

class PurchaseProvider extends ChangeNotifier {
  final PurchaseRepository _repository = PurchaseRepository();
  final PaymentProvider _paymentProvider = PaymentProvider();

  // Consolidated state variables
  List<PurchaseModel> _purchases = [];
  List<ProductModel> _products = [];
  List<UserModel> _vendors = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<PurchaseModel> get purchases => _purchases;
  List<PurchaseModel> get draftPurchases => _purchases.where((p) => p.status == 'draft').toList();
  List<PurchaseModel> get completedPurchases => _purchases.where((p) => p.status == 'completed').toList();
  List<PurchaseModel> get allPurchases => _purchases;
  List<ProductModel> get products => _products;
  List<UserModel> get vendors => _vendors;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Payment provider getters (delegate to payment provider)
  PaymentProvider get paymentProvider => _paymentProvider;

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error state
  void _setError(String error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  // Check if invoice number is unique
  Future<bool> isInvoiceNumberUnique(
    String invoiceNumber, {
    String? excludePurchaseId,
  }) async {
    try {
      _setLoading(true);
      clearError();

      final isUnique = await _repository.isInvoiceNumberUnique(
        invoiceNumber,
        excludePurchaseId: excludePurchaseId,
      );

      _setLoading(false);
      return isUnique;
    } catch (e) {
      _setError('Failed to check invoice number uniqueness: ${e.toString()}');
      return false;
    }
  }

  // Create draft purchase
  Future<bool> createDraftPurchase(
    PurchaseModel purchase,
    List<ItemModel> items,
  ) async {
    try {
      _setLoading(true);
      clearError();

      await _repository.createDraftPurchase(purchase, items);

      // Refresh draft purchases list
      await loadDraftPurchases();

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to create draft purchase: ${e.toString()}');
      return false;
    }
  }

  // Complete purchase (convert draft to completed)
  Future<bool> completePurchase(String purchaseId) async {
    try {
      _setLoading(true);
      clearError();

      await _repository.completePurchase(purchaseId);

      // Refresh draft purchases list
      await loadDraftPurchases();

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to complete purchase: ${e.toString()}');
      return false;
    }
  }

  // Get single purchase
  Future<PurchaseModel?> getPurchase(String purchaseId) async {
    try {
      _setLoading(true);
      clearError();

      final purchase = await _repository.getPurchase(purchaseId);
      _setLoading(false);
      return purchase;
    } catch (e) {
      _setError('Failed to get purchase: ${e.toString()}');
      return null;
    }
  }

  // Load all purchases (includes drafts, completed, returns)
  Future<void> loadAllPurchases() async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError('No internet connection. Please check your connection and try again.');
      return;
    }

    try {
      _setLoading(true);
      clearError();

      _purchases = await _repository.getAllPurchases();
      _setLoading(false);
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError('Connection lost. Please check your internet connection and try again.');
      } else {
        _setError('Failed to load all purchases: ${e.toString()}');
      }
    }
  }

  // Load draft purchases only
  Future<void> loadDraftPurchases() async {
    try {
      _setLoading(true);
      clearError();

      final draftPurchases = await _repository.getDraftPurchases();
      // Update only draft purchases in the main list
      _purchases.removeWhere((p) => p.status == 'draft');
      _purchases.addAll(draftPurchases);
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load draft purchases: ${e.toString()}');
    }
  }

  // Process return with refund method option
  Future<bool> processReturn(
    String originalPurchaseId,
    List<ItemModel> returnItems, {
    String refundMethod = 'credit_adjustment',
  }) async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError('No internet connection. Please check your connection and try again.');
      return false;
    }

    try {
      _setLoading(true);
      clearError();

      await _repository.processReturn(
        originalPurchaseId,
        returnItems,
        refundMethod: refundMethod,
      );

      _setLoading(false);
      return true;
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError('Connection lost. Please check your internet connection and try again.');
      } else {
        _setError('Failed to process return: ${e.toString()}');
      }
      return false;
    }
  }

  // Load products
  Future<void> loadProducts() async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError('No internet connection. Please check your connection and try again.');
      return;
    }

    try {
      _setLoading(true);
      clearError();

      _products = await _repository.getActiveProducts();
      _setLoading(false);
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError('Connection lost. Please check your internet connection and try again.');
      } else {
        _setError('Failed to load products: ${e.toString()}');
      }
    }
  }

  // Load vendors
  Future<void> loadVendors() async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError('No internet connection. Please check your connection and try again.');
      return;
    }

    try {
      _setLoading(true);
      clearError();

      _vendors = await _repository.getVendors();
      _setLoading(false);
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError('Connection lost. Please check your internet connection and try again.');
      } else {
        _setError('Failed to load vendors: ${e.toString()}');
      }
    }
  }

  // Get product by barcode
  Future<ProductModel?> getProductByBarcode(String barcode) async {
    try {
      final product = await _repository.getProductByBarcode(barcode);
      return product;
    } catch (e) {
      debugPrint('Failed to find product by barcode: ${e.toString()}');
      return null;
    }
  }

  // Generate next invoice number
  Future<String> generateInvoiceNumber() async {
    try {
      final invoiceNumber = await _repository.generateInvoiceNumber();
      return invoiceNumber;
    } catch (e) {
      debugPrint('Failed to generate invoice number: ${e.toString()}');
      return 'PUR-0001'; // Fallback
    }
  }

  // Load initial data (products + vendors)
  Future<void> loadInitialData() async {
    await Future.wait([loadProducts(), loadVendors()]);
  }

  // Clear all data
  void clearAllData() {
    _purchases.clear();
    _products.clear();
    _vendors.clear();
    _error = null;
    _isLoading = false;
    _paymentProvider.clearVendorData();
    notifyListeners();
  }

  // Delete draft purchase
  Future<bool> deleteDraftPurchase(String purchaseId) async {
    try {
      _setLoading(true);
      clearError();

      await _repository.deleteDraftPurchase(purchaseId);

      // Refresh draft purchases list
      await loadDraftPurchases();

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to delete draft purchase: ${e.toString()}');
      return false;
    }
  }

  // Get purchase items for a specific purchase
  Future<List<ItemModel>> getPurchaseItems(String purchaseId) async {
    try {
      final items = await _repository.getPurchaseItems(purchaseId);
      return items;
    } catch (e) {
      debugPrint('Failed to get purchase items: ${e.toString()}');
      return [];
    }
  }

  // Get available items for return (items not already returned)
  Future<List<ItemModel>> getAvailableItemsForReturn(String purchaseId) async {
    try {
      return await _repository.getAvailableItemsForReturn(purchaseId);
    } catch (e) {
      debugPrint('Failed to get available items for return: ${e.toString()}');
      return [];
    }
  }

  // Check if a purchase has any returns
  Future<bool> hasReturns(String purchaseId) async {
    try {
      final returns = await _repository.getReturnsForPurchase(purchaseId);
      return returns.isNotEmpty;
    } catch (e) {
      // Don't call _setError during build phase - just return false
      debugPrint('Failed to check returns: ${e.toString()}');
      return false;
    }
  }

  /// Get refund availability for a purchase (how much can be refunded in cash)
  Future<Map<String, double>> getRefundAvailability(
    String userId,
    String purchaseId,
  ) async {
    try {
      return await _repository.getRefundAvailability(userId, purchaseId);
    } catch (e) {
      debugPrint('Failed to get refund availability: $e');
      return {
        'totalPaid': 0.0,
        'totalRefunded': 0.0,
        'availableForRefund': 0.0,
      };
    }
  }
}
