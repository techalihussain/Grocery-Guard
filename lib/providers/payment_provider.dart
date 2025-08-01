import 'package:flutter/foundation.dart';

import '../models/payment_model.dart';
import '../models/purchase_model.dart';
import '../models/sale_model.dart';
import '../repositories/payment_repository.dart';
import '../services/connectivity_service.dart';

class PaymentProvider extends ChangeNotifier {
  final PaymentRepository _repository = PaymentRepository();

  // Consolidated state variables - keeping customer/vendor separation for business logic
  List<PaymentModel> _customerPayments = [];
  List<PaymentModel> _vendorPayments = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<PaymentModel> get customerPayments => _customerPayments;
  List<PaymentModel> get vendorPayments => _vendorPayments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Computed financial totals from payment data
  double get customerTotalDue => _customerPayments.isNotEmpty ? _customerPayments.last.totalDue : 0.0;
  double get customerTotalBalance => _customerPayments.isNotEmpty ? _customerPayments.last.balance : 0.0;
  double get customerTotalPaid => _customerPayments.isNotEmpty ? _customerPayments.last.totalPaid : 0.0;
  double get vendorTotalDue => _vendorPayments.isNotEmpty ? _vendorPayments.last.totalDue : 0.0;
  double get vendorTotalBalance => _vendorPayments.isNotEmpty ? _vendorPayments.last.balance : 0.0;
  double get vendorTotalPaid => _vendorPayments.isNotEmpty ? _vendorPayments.last.totalPaid : 0.0;

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

  // Process customer payment
  Future<bool> processCustomerPayment(
    String userId,
    double amount,
    String paymentMethod,
  ) async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError('No internet connection. Please check your connection and try again.');
      return false;
    }

    try {
      _setLoading(true);
      clearError();

      await _repository.processCustomerPayment(userId, amount, paymentMethod);

      // Refresh all customer data
      await loadCustomerData(userId);

      _setLoading(false);
      return true;
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError('Connection lost. Please check your internet connection and try again.');
      } else {
        _setError('Failed to process payment: ${e.toString()}');
      }
      return false;
    }
  }

  // Record credit sale in payment collection
  Future<bool> recordCreditSale(String userId, SaleModel sale) async {
    try {
      _setLoading(true);
      clearError();

      await _repository.recordCreditSale(userId, sale);

      // Refresh customer data
      await loadCustomerData(userId);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to record credit sale: ${e.toString()}');
      return false;
    }
  }

  // Process return with refund method option
  Future<bool> processReturn(
    String userId,
    SaleModel originalSale,
    SaleModel returnSale, {
    String refundMethod = 'credit_adjustment',
  }) async {
    try {
      _setLoading(true);
      clearError();

      await _repository.processReturn(
        userId,
        originalSale,
        returnSale,
        refundMethod: refundMethod,
      );

      // Refresh customer data
      await loadCustomerData(userId);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to process return: ${e.toString()}');
      return false;
    }
  }

  // Load customer payment history
  Future<void> loadCustomerPayments(String userId) async {
    try {
      _setLoading(true);
      clearError();

      _customerPayments = await _repository.getCustomerPayments(userId);
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load customer payments: ${e.toString()}');
    }
  }

  // Load customer data (payments only - totals are computed)
  Future<void> loadCustomerData(String userId) async {
    await loadCustomerPayments(userId);
  }

  // Get refund availability information for a sale
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

  // Clear customer data
  void clearCustomerData() {
    _customerPayments.clear();
    notifyListeners();
  }

  // ========== VENDOR RELATED METHODS ==========

  // Process vendor payment (we pay the vendor)
  Future<bool> processVendorPayment(
    String vendorId,
    double amount,
    String paymentMethod,
  ) async {
    try {
      _setLoading(true);
      clearError();

      await _repository.processVendorPayment(vendorId, amount, paymentMethod);

      // Refresh all vendor data
      await loadVendorData(vendorId);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to process vendor payment: ${e.toString()}');
      return false;
    }
  }

  // Record credit purchase in payment collection
  Future<bool> recordCreditPurchase(String vendorId, PurchaseModel purchase) async {
    try {
      _setLoading(true);
      clearError();

      await _repository.recordCreditPurchase(vendorId, purchase);

      // Refresh vendor data
      await loadVendorData(vendorId);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to record credit purchase: ${e.toString()}');
      return false;
    }
  }

  // Process purchase return with refund method option
  Future<bool> processPurchaseReturn(
    String vendorId,
    PurchaseModel originalPurchase,
    PurchaseModel returnPurchase, {
    String refundMethod = 'credit_adjustment',
  }) async {
    try {
      _setLoading(true);
      clearError();

      await _repository.processPurchaseReturn(
        vendorId,
        originalPurchase,
        returnPurchase,
        refundMethod: refundMethod,
      );

      // Refresh vendor data
      await loadVendorData(vendorId);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to process purchase return: ${e.toString()}');
      return false;
    }
  }

  // Load vendor payment history
  Future<void> loadVendorPayments(String vendorId) async {
    try {
      _setLoading(true);
      clearError();

      _vendorPayments = await _repository.getVendorPayments(vendorId);
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load vendor payments: ${e.toString()}');
    }
  }

  // Load vendor data (payments only - totals are computed)
  Future<void> loadVendorData(String vendorId) async {
    await loadVendorPayments(vendorId);
  }

  // Get refund availability information for a purchase
  Future<Map<String, double>> getPurchaseRefundAvailability(
    String vendorId,
    String purchaseId,
  ) async {
    try {
      return await _repository.getPurchaseRefundAvailability(vendorId, purchaseId);
    } catch (e) {
      debugPrint('Failed to get purchase refund availability: $e');
      return {
        'totalPaid': 0.0,
        'totalRefunded': 0.0,
        'availableForRefund': 0.0,
      };
    }
  }

  // Clear vendor data
  void clearVendorData() {
    _vendorPayments.clear();
    notifyListeners();
  }
}