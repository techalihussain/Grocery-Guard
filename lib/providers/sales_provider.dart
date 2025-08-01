import 'package:flutter/foundation.dart';

import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../models/sale_purchase_item_model.dart';
import '../models/user_model.dart';
import '../repositories/sales_repository.dart';
import '../services/connectivity_service.dart';
import 'payment_provider.dart';

class SalesProvider extends ChangeNotifier {
  final SalesRepository _repository = SalesRepository();
  final PaymentProvider _paymentProvider = PaymentProvider();

  // Consolidated state variables
  List<SaleModel> _sales = [];
  List<ProductModel> _products = [];
  List<UserModel> _customers = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<SaleModel> get sales => _sales;
  List<SaleModel> get draftSales => _sales.where((s) => s.status == 'draft').toList();
  List<SaleModel> get completedSales => _sales.where((s) => s.status == 'completed').toList();
  List<SaleModel> get allSales => _sales;
  List<ProductModel> get products => _products;
  List<UserModel> get customers => _customers;
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
  Future<bool> isInvoiceNumberUnique(String invoiceNumber, {String? excludeSaleId}) async {
    try {
      _setLoading(true);
      clearError();
      
      final isUnique = await _repository.isInvoiceNumberUnique(
        invoiceNumber, 
        excludeSaleId: excludeSaleId
      );
      
      _setLoading(false);
      return isUnique;
    } catch (e) {
      _setError('Failed to check invoice number uniqueness: ${e.toString()}');
      return false;
    }
  }

  // Validate stock availability
  Future<bool> validateStock(List<ItemModel> items) async {
    try {
      _setLoading(true);
      clearError();

      final isValid = await _repository.validateStockAvailability(items);
      _setLoading(false);
      return isValid;
    } catch (e) {
      _setError('Stock validation failed: ${e.toString()}');
      return false;
    }
  }

  // Create draft sale
  Future<bool> createDraftSale(SaleModel sale, List<ItemModel> items) async {
    try {
      _setLoading(true);
      clearError();

      // Validate stock first
      final stockValid = await _repository.validateStockAvailability(items);
      if (!stockValid) {
        _setError('Insufficient stock for one or more items');
        return false;
      }

      await _repository.createDraftSale(sale, items);

      // Refresh draft sales list
      await loadDraftSales();

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to create draft sale: ${e.toString()}');
      return false;
    }
  }

  // Complete sale (convert draft to completed)
  Future<bool> completeSale(String saleId) async {
    try {
      _setLoading(true);
      clearError();

      await _repository.completeSale(saleId);

      // Refresh draft sales list
      await loadDraftSales();

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to complete sale: ${e.toString()}');
      return false;
    }
  }

  // Get single sale
  Future<SaleModel?> getSale(String saleId) async {
    try {
      _setLoading(true);
      clearError();

      final sale = await _repository.getSale(saleId);
      _setLoading(false);
      return sale;
    } catch (e) {
      _setError('Failed to get sale: ${e.toString()}');
      return null;
    }
  }

  // Load all sales (includes drafts, completed, returns)
  Future<void> loadAllSales() async {
    try {
      _setLoading(true);
      clearError();

      // Check connectivity before making network call
      if (!ConnectivityService().isConnected) {
        _setError('No internet connection. Please check your connection and try again.');
        return;
      }

      _sales = await _repository.getAllSales();
      _setLoading(false);
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError('Connection lost. Please check your internet connection and try again.');
      } else {
        _setError('Failed to load all sales: ${e.toString()}');
      }
    }
  }

  // Load draft sales only
  Future<void> loadDraftSales() async {
    try {
      _setLoading(true);
      clearError();

      final draftSales = await _repository.getDraftSales();
      // Update only draft sales in the main list
      _sales.removeWhere((s) => s.status == 'draft');
      _sales.addAll(draftSales);
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load draft sales: ${e.toString()}');
    }
  }

  // Process return with refund method option
  Future<bool> processReturn(
    String originalSaleId,
    List<ItemModel> returnItems, {
    String refundMethod = 'credit_adjustment',
  }) async {
    try {
      _setLoading(true);
      clearError();

      await _repository.processReturn(
        originalSaleId,
        returnItems,
        refundMethod: refundMethod,
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to process return: ${e.toString()}');
      return false;
    }
  }

  // Load products
  Future<void> loadProducts() async {
    try {
      _setLoading(true);
      clearError();

      _products = await _repository.getActiveProducts();
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load products: ${e.toString()}');
    }
  }

  // Load customers
  Future<void> loadCustomers() async {
    try {
      _setLoading(true);
      clearError();

      _customers = await _repository.getCustomers();
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load customers: ${e.toString()}');
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
      return 'INV-0001'; // Fallback
    }
  }

  // Load initial data (products + customers)
  Future<void> loadInitialData() async {
    await Future.wait([loadProducts(), loadCustomers()]);
  }

  // Clear all data
  void clearAllData() {
    _sales.clear();
    _products.clear();
    _customers.clear();
    _error = null;
    _isLoading = false;
    _paymentProvider.clearCustomerData();
    notifyListeners();
  }

  // Delete draft sale
  Future<bool> deleteDraftSale(String saleId) async {
    try {
      _setLoading(true);
      clearError();

      await _repository.deleteDraftSale(saleId);

      // Refresh draft sales list
      await loadDraftSales();

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to delete draft sale: ${e.toString()}');
      return false;
    }
  }

  // Get sale items for a specific sale
  Future<List<ItemModel>> getSaleItems(String saleId) async {
    try {
      final items = await _repository.getSaleItems(saleId);
      return items;
    } catch (e) {
      debugPrint('Failed to get sale items: ${e.toString()}');
      return [];
    }
  }

  // Get available items for return (items not already returned)
  Future<List<ItemModel>> getAvailableItemsForReturn(String saleId) async {
    try {
      return await _repository.getAvailableItemsForReturn(saleId);
    } catch (e) {
      debugPrint('Failed to get available items for return: ${e.toString()}');
      return [];
    }
  }

  // Check if a sale has any returns
  Future<bool> hasReturns(String saleId) async {
    try {
      final returns = await _repository.getReturnsForSale(saleId);
      return returns.isNotEmpty;
    } catch (e) {
      // Don't call _setError during build phase - just return false
      debugPrint('Failed to check returns: ${e.toString()}');
      return false;
    }
  }

  /// Get refund availability for a sale (how much can be refunded in cash)
  Future<Map<String, double>> getRefundAvailability(
    String userId,
    String saleId,
  ) async {
    try {
      return await _repository.getRefundAvailability(userId, saleId);
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