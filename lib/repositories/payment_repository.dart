import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/payment_model.dart';
import '../models/purchase_model.dart';
import '../models/sale_model.dart';

class PaymentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get customer's latest payment record
  Future<PaymentModel?> getLatestPayment(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('payments')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return PaymentModel.fromJson(snapshot.docs.first.data());
    } catch (e) {
      throw Exception('Error getting latest payment: $e');
    }
  }

  // Get customer payment history
  Future<List<PaymentModel>> getCustomerPayments(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('payments')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PaymentModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error getting customer payments: $e');
    }
  }

  // Get customer's current total balance (all credit sales)
  Future<double> getCustomerTotalBalance(String userId, {String? excludeSaleId}) async {
    try {
      // First try to get the latest payment record for efficiency
      final latestPayment = await getLatestPayment(userId);
      if (latestPayment != null && excludeSaleId == null) {
        return latestPayment.balance;
      }
      
      // If no payment record exists or we need to exclude a specific sale, calculate from sales
      final salesSnapshot = await _firestore
          .collection('sales')
          .where('customerId', isEqualTo: userId)
          .where('isCredit', isEqualTo: true)
          .where('status', isEqualTo: 'completed')
          .get();

      double totalBalance = 0.0;
      for (var doc in salesSnapshot.docs) {
        // Skip the sale if it's the one we want to exclude
        if (excludeSaleId != null && doc.id == excludeSaleId) continue;
        
        final sale = SaleModel.fromJson(doc.data());
        if (sale.isReturn) {
          // For returns, subtract the amount (returns have negative totalAmount)
          totalBalance += sale.totalAmount; // This will subtract since totalAmount is negative
        } else {
          // For regular sales, add the amount
          totalBalance += sale.totalAmount;
        }
      }

      return totalBalance;
    } catch (e) {
      throw Exception('Error getting customer total balance: $e');
    }
  }

  // Get customer's total paid amount (from all payment records)
  Future<double> getCustomerTotalPaid(String userId) async {
    try {
      final latestPayment = await getLatestPayment(userId);
      if (latestPayment != null) {
        return latestPayment.totalPaid;
      }
      
      // If no payment record exists, calculate from payment records
      final paymentsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('payments')
          .where('type', isEqualTo: 'payment')
          .get();

      double totalPaid = 0.0;
      for (var doc in paymentsSnapshot.docs) {
        final payment = PaymentModel.fromJson(doc.data());
        totalPaid += payment.paymentAmount; // Use paymentAmount instead of totalPaid
      }

      return totalPaid;
    } catch (e) {
      throw Exception('Error getting customer total paid: $e');
    }
  }

  // Get customer's current total due (balance - totalPaid)
  Future<double> getCustomerTotalDue(String userId) async {
    try {
      final balance = await getCustomerTotalBalance(userId);
      final totalPaid = await getCustomerTotalPaid(userId);
      return balance - totalPaid;
    } catch (e) {
      throw Exception('Error getting customer total due: $e');
    }
  }

  // Process customer payment
  Future<void> processCustomerPayment(
    String userId,
    double amount,
    String paymentMethod,
  ) async {
    try {
      // Get the latest payment record first for accurate values
      final latestPayment = await getLatestPayment(userId);
      double currentBalance;
      double currentTotalPaid;
      
      if (latestPayment != null) {
        // If we have a payment record, use its values
        currentBalance = latestPayment.balance;
        currentTotalPaid = latestPayment.totalPaid;
      } else {
        // If no payment record exists, calculate from sales
        currentBalance = await getCustomerTotalBalance(userId);
        currentTotalPaid = await getCustomerTotalPaid(userId);
      }
      
      final currentDue = currentBalance - currentTotalPaid;

      if (currentDue <= 0) {
        throw Exception('No outstanding balance for this customer');
      }

      if (amount > currentDue) {
        throw Exception('Payment amount cannot exceed total due');
      }

      // Calculate new values
      final newTotalPaid = currentTotalPaid + amount;
      final newTotalDue = currentBalance - newTotalPaid;

      final paymentModel = PaymentModel(
        id: _firestore.collection('temp').doc().id,
        balance: currentBalance, // Keep the same balance
        totalPaid: newTotalPaid, // Increase total paid
        totalDue: newTotalDue, // Decrease total due
        paymentAmount: amount, // Individual payment amount
        createdAt: DateTime.now(),
        referenceId: '',
        type: 'payment',
        paymentMethod: paymentMethod,
        description: 'Payment received - $paymentMethod',
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('payments')
          .doc(paymentModel.id)
          .set(paymentModel.toJson());
    } catch (e) {
      throw Exception('Error processing payment: $e');
    }
  }

  // Record credit sale in payment collection
  Future<void> recordCreditSale(String userId, SaleModel sale) async {
    try {
      // Get current customer's balance and total paid
      // We need to be careful not to double-count the sale that was just added
      
      // Get the latest payment record first
      final latestPayment = await getLatestPayment(userId);
      double currentBalance;
      double currentTotalPaid;
      
      if (latestPayment != null) {
        // If we have a payment record, use its values
        currentBalance = latestPayment.balance;
        currentTotalPaid = latestPayment.totalPaid;
      } else {
        // If no payment record exists, calculate from sales
        // IMPORTANT: We must exclude the current sale to avoid double-counting
        // since it's already been marked as completed in the database
        currentBalance = await getCustomerTotalBalance(userId, excludeSaleId: sale.id);
        
        // Get total paid separately
        currentTotalPaid = await getCustomerTotalPaid(userId);
      }

      // Now add the new sale amount to the balance
      final newBalance = currentBalance + sale.totalAmount;
      final newTotalDue = newBalance - currentTotalPaid;

      // Create payment record for credit sale
      final paymentModel = PaymentModel(
        id: _firestore.collection('temp').doc().id,
        balance: newBalance,
        totalPaid: currentTotalPaid,
        totalDue: newTotalDue,
        paymentAmount: sale.totalAmount, // Use sale amount as payment amount
        createdAt: DateTime.now(),
        referenceId: sale.id,
        type: 'credit_sale',
        paymentMethod: null,
        description: 'Credit Sale #${sale.invoiceNo}',
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('payments')
          .doc(paymentModel.id)
          .set(paymentModel.toJson());
    } catch (e) {
      throw Exception('Error recording credit sale: $e');
    }
  }

  // Process return with refund option (cash or credit adjustment)
  Future<void> processReturn(
    String userId,
    SaleModel originalSale,
    SaleModel returnSale, {
    String refundMethod = 'credit_adjustment', // 'credit_adjustment' or 'cash_refund'
  }) async {
    try {
      final returnAmount = returnSale.totalAmount.abs(); // Make positive for calculations
      
      // For cash sales, no payment record is needed for returns
      if (!originalSale.isCredit) {
        // Cash sales don't affect payment collection, just handle as cash refund
        return; // No payment record needed
      }

      // Get the latest payment record first for accurate values
      final latestPayment = await getLatestPayment(userId);
      double currentBalance;
      double currentTotalPaid;
      
      if (latestPayment != null) {
        // If we have a payment record, use its values
        currentBalance = latestPayment.balance;
        currentTotalPaid = latestPayment.totalPaid;
      } else {
        // If no payment record exists, calculate from sales
        // But exclude the current return to avoid double-counting
        currentBalance = await getCustomerTotalBalance(userId, excludeSaleId: returnSale.id);
        
        // Get total paid separately
        currentTotalPaid = await getCustomerTotalPaid(userId);
      }

      // For credit sales, handle based on refund method
      if (refundMethod == 'credit_adjustment') {
        // Credit adjustment: reduce customer's balance
        final newBalance = currentBalance - returnAmount; // Reduce balance
        final newTotalDue = newBalance - currentTotalPaid;

        final paymentModel = PaymentModel(
          id: _firestore.collection('temp').doc().id,
          balance: newBalance,
          totalPaid: currentTotalPaid,
          totalDue: newTotalDue,
          paymentAmount: -returnAmount, // Negative amount for return
          createdAt: DateTime.now(),
          referenceId: returnSale.id,
          type: 'credit_adjustment',
          paymentMethod: null,
          description: 'Return - Credit adjustment for #${originalSale.invoiceNo}',
        );

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('payments')
            .doc(paymentModel.id)
            .set(paymentModel.toJson());
      } else if (refundMethod == 'cash_refund') {
        // Cash refund: validate available refund amount first
        final refundAvailability = await getRefundAvailability(userId, originalSale.id);
        final availableForRefund = refundAvailability['availableForRefund'] ?? 0.0;

        if (returnAmount > availableForRefund) {
          throw Exception(
            'Cannot refund \$${returnAmount.toStringAsFixed(2)} in cash. '
            'Maximum cash refund available: \$${availableForRefund.toStringAsFixed(2)}',
          );
        }

        // Cash refund without affecting balance - customer gets cash back
        // but their credit balance remains unchanged
        // IMPORTANT: For cash refunds, we should NOT change the balance or totalPaid
        // in terms of the customer's credit account. The cash refund is handled separately.
        final paymentModel = PaymentModel(
          id: _firestore.collection('temp').doc().id,
          balance: currentBalance, // Keep balance unchanged
          totalPaid: currentTotalPaid, // Keep total paid unchanged
          totalDue: currentBalance - currentTotalPaid, // Keep total due unchanged
          paymentAmount: -returnAmount, // Negative amount for refund (for record-keeping only)
          createdAt: DateTime.now(),
          referenceId: returnSale.id,
          type: 'cash_refund',
          paymentMethod: 'cash',
          description: 'Return - Cash refund for #${originalSale.invoiceNo}',
        );

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('payments')
            .doc(paymentModel.id)
            .set(paymentModel.toJson());
      }
    } catch (e) {
      throw Exception('Error processing return payment: $e');
    }
  }

  // Get total amount paid by customer for a specific sale
  Future<double> getCustomerTotalPaidForSale(String userId, String saleId) async {
    try {
      // First check if this is a cash sale
      final saleDoc = await _firestore.collection('sales').doc(saleId).get();
      if (!saleDoc.exists) {
        return 0.0;
      }

      final sale = SaleModel.fromJson(saleDoc.data()!);

      // For cash sales, the full amount was paid in cash
      if (!sale.isCredit) {
        return sale.totalAmount;
      }

      // For credit sales, we need to find all payments specifically for this sale
      // or general payments that could be used for any sale
      final paymentsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('payments')
          .where('type', isEqualTo: 'payment')
          .get();

      double totalPaid = 0.0;
      for (var doc in paymentsSnapshot.docs) {
        final payment = PaymentModel.fromJson(doc.data());
        // Include payments specifically for this sale or general payments
        if (payment.referenceId == saleId ||
            payment.referenceId == '' ||
            payment.referenceId.isEmpty) {
          totalPaid += payment.paymentAmount;
        }
      }

      return totalPaid;
    } catch (e) {
      throw Exception('Error getting customer total paid for sale: $e');
    }
  }

  // Get total amount already refunded for a specific sale
  Future<double> getTotalRefundedForSale(String userId, String saleId) async {
    try {
      // First check if this is a cash sale
      final saleDoc = await _firestore.collection('sales').doc(saleId).get();
      if (!saleDoc.exists) {
        return 0.0;
      }

      final sale = SaleModel.fromJson(saleDoc.data()!);

      // For cash sales, calculate refunds from return sale records instead of payment records
      if (!sale.isCredit) {
        final returnsSnapshot = await _firestore
            .collection('sales')
            .where('originalId', isEqualTo: saleId)
            .where('isReturn', isEqualTo: true)
            .get();

        double totalRefunded = 0.0;
        for (var returnDoc in returnsSnapshot.docs) {
          final returnSale = SaleModel.fromJson(returnDoc.data());
          totalRefunded += returnSale.totalAmount.abs(); // totalAmount is negative for returns
        }

        return totalRefunded;
      }

      // For credit sales, check payment records for both cash refunds and credit adjustments
      final returnsSnapshot = await _firestore
          .collection('sales')
          .where('originalId', isEqualTo: saleId)
          .where('isReturn', isEqualTo: true)
          .get();

      double totalRefunded = 0.0;

      // For each return, find the corresponding payment record
      for (var returnDoc in returnsSnapshot.docs) {
        final returnSale = SaleModel.fromJson(returnDoc.data());

        // Look for payment records with this return sale ID as reference
        final paymentSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('payments')
            .where('referenceId', isEqualTo: returnSale.id)
            .get();

        for (var paymentDoc in paymentSnapshot.docs) {
          final payment = PaymentModel.fromJson(paymentDoc.data());
          if (payment.type == 'cash_refund') {
            // Use the paymentAmount field which contains the actual refund amount
            // This is negative for refunds, so we need to take the absolute value
            totalRefunded += payment.paymentAmount.abs();
          }
        }
      }

      return totalRefunded;
    } catch (e) {
      throw Exception('Error getting total refunded for sale: $e');
    }
  }

  // Get refund availability information for a sale
  Future<Map<String, double>> getRefundAvailability(
    String userId,
    String saleId,
  ) async {
    try {
      final totalPaid = await getCustomerTotalPaidForSale(userId, saleId);
      final totalRefunded = await getTotalRefundedForSale(userId, saleId);
      final availableForRefund = totalPaid - totalRefunded;

      return {
        'totalPaid': totalPaid,
        'totalRefunded': totalRefunded,
        'availableForRefund': availableForRefund,
      };
    } catch (e) {
      throw Exception('Error getting refund availability: $e');
    }
  }

  // ========== PURCHASE RELATED METHODS ==========

  // Get vendor's latest payment record
  Future<PaymentModel?> getLatestVendorPayment(String vendorId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(vendorId)
          .collection('payments')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return PaymentModel.fromJson(snapshot.docs.first.data());
    } catch (e) {
      throw Exception('Error getting latest vendor payment: $e');
    }
  }

  // Get vendor payment history
  Future<List<PaymentModel>> getVendorPayments(String vendorId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(vendorId)
          .collection('payments')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PaymentModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error getting vendor payments: $e');
    }
  }

  // Get vendor's current total balance (all credit purchases - what we owe them)
  Future<double> getVendorTotalBalance(String vendorId, {String? excludePurchaseId}) async {
    try {
      // First try to get the latest payment record for efficiency
      final latestPayment = await getLatestVendorPayment(vendorId);
      if (latestPayment != null && excludePurchaseId == null) {
        return latestPayment.balance;
      }
      
      // If no payment record exists or we need to exclude a specific purchase, calculate from purchases
      final purchasesSnapshot = await _firestore
          .collection('purchases')
          .where('vendorId', isEqualTo: vendorId)
          .where('isCredit', isEqualTo: true)
          .where('status', isEqualTo: 'completed')
          .get();

      double totalBalance = 0.0;
      for (var doc in purchasesSnapshot.docs) {
        // Skip the purchase if it's the one we want to exclude
        if (excludePurchaseId != null && doc.id == excludePurchaseId) continue;
        
        final purchase = PurchaseModel.fromJson(doc.data());
        if (purchase.isReturn) {
          // For returns, subtract the amount (returns have negative totalAmount)
          totalBalance += purchase.totalAmount; // This will subtract since totalAmount is negative
        } else {
          // For regular purchases, add the amount
          totalBalance += purchase.totalAmount;
        }
      }

      return totalBalance;
    } catch (e) {
      throw Exception('Error getting vendor total balance: $e');
    }
  }

  // Get vendor's total paid amount (from all payment records - what we've paid them)
  Future<double> getVendorTotalPaid(String vendorId) async {
    try {
      final latestPayment = await getLatestVendorPayment(vendorId);
      if (latestPayment != null) {
        return latestPayment.totalPaid;
      }
      
      // If no payment record exists, calculate from payment records
      final paymentsSnapshot = await _firestore
          .collection('users')
          .doc(vendorId)
          .collection('payments')
          .where('type', isEqualTo: 'vendor_payment')
          .get();

      double totalPaid = 0.0;
      for (var doc in paymentsSnapshot.docs) {
        final payment = PaymentModel.fromJson(doc.data());
        totalPaid += payment.paymentAmount; // Use paymentAmount instead of totalPaid
      }

      return totalPaid;
    } catch (e) {
      throw Exception('Error getting vendor total paid: $e');
    }
  }

  // Get vendor's current total due (balance - totalPaid - what we still owe them)
  Future<double> getVendorTotalDue(String vendorId) async {
    try {
      final balance = await getVendorTotalBalance(vendorId);
      final totalPaid = await getVendorTotalPaid(vendorId);
      return balance - totalPaid;
    } catch (e) {
      throw Exception('Error getting vendor total due: $e');
    }
  }

  // Process vendor payment (we pay the vendor)
  Future<void> processVendorPayment(
    String vendorId,
    double amount,
    String paymentMethod,
  ) async {
    try {
      // Get the latest payment record first for accurate values
      final latestPayment = await getLatestVendorPayment(vendorId);
      double currentBalance;
      double currentTotalPaid;
      
      if (latestPayment != null) {
        // If we have a payment record, use its values
        currentBalance = latestPayment.balance;
        currentTotalPaid = latestPayment.totalPaid;
      } else {
        // If no payment record exists, calculate from purchases
        currentBalance = await getVendorTotalBalance(vendorId);
        currentTotalPaid = await getVendorTotalPaid(vendorId);
      }
      
      final currentDue = currentBalance - currentTotalPaid;

      if (currentDue <= 0) {
        throw Exception('No outstanding balance for this vendor');
      }

      if (amount > currentDue) {
        throw Exception('Payment amount cannot exceed total due');
      }

      // Calculate new values
      final newTotalPaid = currentTotalPaid + amount;
      final newTotalDue = currentBalance - newTotalPaid;

      final paymentModel = PaymentModel(
        id: _firestore.collection('temp').doc().id,
        balance: currentBalance, // Keep the same balance
        totalPaid: newTotalPaid, // Increase total paid
        totalDue: newTotalDue, // Decrease total due
        paymentAmount: amount, // Individual payment amount
        createdAt: DateTime.now(),
        referenceId: '',
        type: 'vendor_payment',
        paymentMethod: paymentMethod,
        description: 'Payment made to vendor - $paymentMethod',
      );

      await _firestore
          .collection('users')
          .doc(vendorId)
          .collection('payments')
          .doc(paymentModel.id)
          .set(paymentModel.toJson());
    } catch (e) {
      throw Exception('Error processing vendor payment: $e');
    }
  }

  // Record credit purchase in payment collection
  Future<void> recordCreditPurchase(String vendorId, PurchaseModel purchase) async {
    try {
      // Get current vendor's balance and total paid
      // We need to be careful not to double-count the purchase that was just added
      
      // Get the latest payment record first
      final latestPayment = await getLatestVendorPayment(vendorId);
      double currentBalance;
      double currentTotalPaid;
      
      if (latestPayment != null) {
        // If we have a payment record, use its values
        currentBalance = latestPayment.balance;
        currentTotalPaid = latestPayment.totalPaid;
      } else {
        // If no payment record exists, calculate from purchases
        // IMPORTANT: We must exclude the current purchase to avoid double-counting
        // since it's already been marked as completed in the database
        currentBalance = await getVendorTotalBalance(vendorId, excludePurchaseId: purchase.id);
        
        // Get total paid separately
        currentTotalPaid = await getVendorTotalPaid(vendorId);
      }

      // Now add the new purchase amount to the balance
      final newBalance = currentBalance + purchase.totalAmount;
      final newTotalDue = newBalance - currentTotalPaid;

      // Create payment record for credit purchase
      final paymentModel = PaymentModel(
        id: _firestore.collection('temp').doc().id,
        balance: newBalance,
        totalPaid: currentTotalPaid,
        totalDue: newTotalDue,
        paymentAmount: purchase.totalAmount, // Use purchase amount as payment amount
        createdAt: DateTime.now(),
        referenceId: purchase.id,
        type: 'credit_purchase',
        paymentMethod: null,
        description: 'Credit Purchase #${purchase.invoiceNo}',
      );

      await _firestore
          .collection('users')
          .doc(vendorId)
          .collection('payments')
          .doc(paymentModel.id)
          .set(paymentModel.toJson());
    } catch (e) {
      throw Exception('Error recording credit purchase: $e');
    }
  }

  // Process purchase return with refund option (cash or credit adjustment)
  Future<void> processPurchaseReturn(
    String vendorId,
    PurchaseModel originalPurchase,
    PurchaseModel returnPurchase, {
    String refundMethod = 'credit_adjustment', // 'credit_adjustment' or 'cash_refund'
  }) async {
    try {
      final returnAmount = returnPurchase.totalAmount.abs(); // Make positive for calculations
      
      // For cash purchases, no payment record is needed for returns
      if (!originalPurchase.isCredit) {
        // Cash purchases don't affect payment collection, just handle as cash refund
        return; // No payment record needed
      }

      // Get the latest payment record first for accurate values
      final latestPayment = await getLatestVendorPayment(vendorId);
      double currentBalance;
      double currentTotalPaid;
      
      if (latestPayment != null) {
        // If we have a payment record, use its values
        currentBalance = latestPayment.balance;
        currentTotalPaid = latestPayment.totalPaid;
      } else {
        // If no payment record exists, calculate from purchases
        // But exclude the current return to avoid double-counting
        currentBalance = await getVendorTotalBalance(vendorId, excludePurchaseId: returnPurchase.id);
        
        // Get total paid separately
        currentTotalPaid = await getVendorTotalPaid(vendorId);
      }

      // For credit purchases, handle based on refund method
      if (refundMethod == 'credit_adjustment') {
        // Credit adjustment: reduce vendor's balance (we owe them less)
        final newBalance = currentBalance - returnAmount; // Reduce balance
        final newTotalDue = newBalance - currentTotalPaid;

        final paymentModel = PaymentModel(
          id: _firestore.collection('temp').doc().id,
          balance: newBalance,
          totalPaid: currentTotalPaid,
          totalDue: newTotalDue,
          paymentAmount: -returnAmount, // Negative amount for return
          createdAt: DateTime.now(),
          referenceId: returnPurchase.id,
          type: 'purchase_credit_adjustment',
          paymentMethod: null,
          description: 'Purchase Return - Credit adjustment for #${originalPurchase.invoiceNo}',
        );

        await _firestore
            .collection('users')
            .doc(vendorId)
            .collection('payments')
            .doc(paymentModel.id)
            .set(paymentModel.toJson());
      } else if (refundMethod == 'cash_refund') {
        // Cash refund: validate available refund amount first
        final refundAvailability = await getPurchaseRefundAvailability(vendorId, originalPurchase.id);
        final availableForRefund = refundAvailability['availableForRefund'] ?? 0.0;

        if (returnAmount > availableForRefund) {
          throw Exception(
            'Cannot refund \${returnAmount.toStringAsFixed(2)} in cash. '
            'Maximum cash refund available: \${availableForRefund.toStringAsFixed(2)}',
          );
        }

        // Cash refund without affecting balance - vendor gets cash back
        // but their credit balance remains unchanged
        final paymentModel = PaymentModel(
          id: _firestore.collection('temp').doc().id,
          balance: currentBalance, // Keep balance unchanged
          totalPaid: currentTotalPaid, // Keep total paid unchanged
          totalDue: currentBalance - currentTotalPaid, // Keep total due unchanged
          paymentAmount: -returnAmount, // Negative amount for refund (for record-keeping only)
          createdAt: DateTime.now(),
          referenceId: returnPurchase.id,
          type: 'purchase_cash_refund',
          paymentMethod: 'cash',
          description: 'Purchase Return - Cash refund for #${originalPurchase.invoiceNo}',
        );

        await _firestore
            .collection('users')
            .doc(vendorId)
            .collection('payments')
            .doc(paymentModel.id)
            .set(paymentModel.toJson());
      }
    } catch (e) {
      throw Exception('Error processing purchase return payment: $e');
    }
  }

  // Get total amount paid to vendor for a specific purchase
  Future<double> getVendorTotalPaidForPurchase(String vendorId, String purchaseId) async {
    try {
      // First check if this is a cash purchase
      final purchaseDoc = await _firestore.collection('purchases').doc(purchaseId).get();
      if (!purchaseDoc.exists) {
        return 0.0;
      }

      final purchase = PurchaseModel.fromJson(purchaseDoc.data()!);

      // For cash purchases, the full amount was paid in cash
      if (!purchase.isCredit) {
        return purchase.totalAmount;
      }

      // For credit purchases, we need to find all payments specifically for this purchase
      // or general payments that could be used for any purchase
      final paymentsSnapshot = await _firestore
          .collection('users')
          .doc(vendorId)
          .collection('payments')
          .where('type', isEqualTo: 'vendor_payment')
          .get();

      double totalPaid = 0.0;
      for (var doc in paymentsSnapshot.docs) {
        final payment = PaymentModel.fromJson(doc.data());
        // Include payments specifically for this purchase or general payments
        if (payment.referenceId == purchaseId ||
            payment.referenceId == '' ||
            payment.referenceId.isEmpty) {
          totalPaid += payment.paymentAmount;
        }
      }

      return totalPaid;
    } catch (e) {
      throw Exception('Error getting vendor total paid for purchase: $e');
    }
  }

  // Get total amount already refunded for a specific purchase
  Future<double> getTotalRefundedForPurchase(String vendorId, String purchaseId) async {
    try {
      // First check if this is a cash purchase
      final purchaseDoc = await _firestore.collection('purchases').doc(purchaseId).get();
      if (!purchaseDoc.exists) {
        return 0.0;
      }

      final purchase = PurchaseModel.fromJson(purchaseDoc.data()!);

      // For cash purchases, calculate refunds from return purchase records instead of payment records
      if (!purchase.isCredit) {
        final returnsSnapshot = await _firestore
            .collection('purchases')
            .where('originalId', isEqualTo: purchaseId)
            .where('isReturn', isEqualTo: true)
            .get();

        double totalRefunded = 0.0;
        for (var returnDoc in returnsSnapshot.docs) {
          final returnPurchase = PurchaseModel.fromJson(returnDoc.data());
          totalRefunded += returnPurchase.totalAmount.abs(); // totalAmount is negative for returns
        }

        return totalRefunded;
      }

      // For credit purchases, check payment records for both cash refunds and credit adjustments
      final returnsSnapshot = await _firestore
          .collection('purchases')
          .where('originalId', isEqualTo: purchaseId)
          .where('isReturn', isEqualTo: true)
          .get();

      double totalRefunded = 0.0;

      // For each return, find the corresponding payment record
      for (var returnDoc in returnsSnapshot.docs) {
        final returnPurchase = PurchaseModel.fromJson(returnDoc.data());

        // Look for payment records with this return purchase ID as reference
        final paymentSnapshot = await _firestore
            .collection('users')
            .doc(vendorId)
            .collection('payments')
            .where('referenceId', isEqualTo: returnPurchase.id)
            .get();

        for (var paymentDoc in paymentSnapshot.docs) {
          final payment = PaymentModel.fromJson(paymentDoc.data());
          if (payment.type == 'purchase_cash_refund') {
            // Use the paymentAmount field which contains the actual refund amount
            // This is negative for refunds, so we need to take the absolute value
            totalRefunded += payment.paymentAmount.abs();
          }
        }
      }

      return totalRefunded;
    } catch (e) {
      throw Exception('Error getting total refunded for purchase: $e');
    }
  }

  // Get refund availability information for a purchase
  Future<Map<String, double>> getPurchaseRefundAvailability(
    String vendorId,
    String purchaseId,
  ) async {
    try {
      final totalPaid = await getVendorTotalPaidForPurchase(vendorId, purchaseId);
      final totalRefunded = await getTotalRefundedForPurchase(vendorId, purchaseId);
      final availableForRefund = totalPaid - totalRefunded;

      return {
        'totalPaid': totalPaid,
        'totalRefunded': totalRefunded,
        'availableForRefund': availableForRefund,
      };
    } catch (e) {
      throw Exception('Error getting purchase refund availability: $e');
    }
  }
}