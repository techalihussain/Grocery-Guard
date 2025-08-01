import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/payment_model.dart';
import '../../providers/payment_provider.dart';
import '../../providers/purchase_provider.dart';

class VendorPaymentsScreen extends StatefulWidget {
  const VendorPaymentsScreen({super.key});

  @override
  State<VendorPaymentsScreen> createState() => _VendorPaymentsScreenState();
}

class _VendorPaymentsScreenState extends State<VendorPaymentsScreen> {
  String? _selectedVendorId;
  final _paymentController = TextEditingController();
  String _paymentMethod = 'cash';
  
  // Helper method to show loading dialog
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  // Helper method to hide loading dialog
  void _hideLoadingDialog() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVendors();
    });
  }

  void _loadVendors() async {
    final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
    try {
      await purchaseProvider.loadVendors();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load vendors: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _loadVendorData(String vendorId) async {
    _showLoadingDialog('Loading vendor data...');
    
    try {
      final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
      await paymentProvider.loadVendorData(vendorId);
      _hideLoadingDialog();
    } catch (e) {
      _hideLoadingDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load vendor data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchaseProvider = Provider.of<PurchaseProvider>(context);
    final paymentProvider = Provider.of<PaymentProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Payments'),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_selectedVendorId != null) {
                _loadVendorData(_selectedVendorId!);
              }
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVendorSelection(purchaseProvider),
            const SizedBox(height: 20),
            if (_selectedVendorId != null) ...[
              _buildVendorSummary(paymentProvider),
              const SizedBox(height: 20),
              _buildPaymentForm(paymentProvider),
              const SizedBox(height: 20),
              _buildPaymentHistory(paymentProvider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVendorSelection(PurchaseProvider purchaseProvider) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Vendor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedVendorId,
              decoration: const InputDecoration(
                labelText: 'Vendor',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              items: purchaseProvider.vendors.map((vendor) {
                return DropdownMenuItem(
                  value: vendor.id,
                  child: SizedBox(
                    width: screenWidth * 0.5,
                    child: Text(
                      '${vendor.name} - ${vendor.phoneNumber}',
                      style: const TextStyle(overflow: TextOverflow.ellipsis),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedVendorId = value;
                });
                if (value != null) {
                  _loadVendorData(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorSummary(PaymentProvider paymentProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade50, Colors.purple.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 48,
                    color: Colors.purple.shade600,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount Due to Vendor',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '\$${paymentProvider.vendorTotalDue.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: paymentProvider.vendorTotalDue > 0
                                ? Colors.red.shade600
                                : Colors.green.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Balance',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    '\$${paymentProvider.vendorTotalBalance.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Paid',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    '\$${paymentProvider.vendorTotalPaid.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentForm(PaymentProvider paymentProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Make Payment to Vendor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _paymentController,
              decoration: const InputDecoration(
                labelText: 'Payment Amount',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                prefixText: '\$ ',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildPaymentMethodChip('cash', 'Cash', Icons.money),
                _buildPaymentMethodChip('card', 'Card', Icons.credit_card),
                _buildPaymentMethodChip(
                  'bank_transfer',
                  'Bank Transfer',
                  Icons.account_balance,
                ),
                _buildPaymentMethodChip('check', 'Check', Icons.receipt),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: paymentProvider.vendorTotalDue > 0
                    ? () => _processPayment(paymentProvider)
                    : null,
                icon: const Icon(Icons.payment),
                label: const Text('Make Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodChip(String value, String label, IconData icon) {
    final isSelected = _paymentMethod == value;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(label)],
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _paymentMethod = value;
          });
        }
      },
      selectedColor: Colors.purple.shade100,
      checkmarkColor: Colors.purple.shade700,
    );
  }

  Widget _buildPaymentHistory(PaymentProvider paymentProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (paymentProvider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (paymentProvider.vendorPayments.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No payment history',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: paymentProvider.vendorPayments.length,
                itemBuilder: (context, index) {
                  final payment = paymentProvider.vendorPayments[index];
                  return _buildPaymentHistoryItem(payment);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistoryItem(PaymentModel payment) {
    IconData icon;
    Color iconColor;
    Color backgroundColor;
    Color borderColor;
    String amountText;
    
    switch (payment.type) {
      case 'vendor_payment':
        icon = Icons.arrow_upward;
        iconColor = Colors.green.shade700;
        backgroundColor = Colors.green.shade50;
        borderColor = Colors.green.shade200;
        amountText = '-\$${payment.paymentAmount.toStringAsFixed(2)}';
        break;
      case 'credit_purchase':
        icon = Icons.shopping_cart;
        iconColor = Colors.red.shade700;
        backgroundColor = Colors.red.shade50;
        borderColor = Colors.red.shade200;
        amountText = '+\$${payment.paymentAmount.toStringAsFixed(2)}';
        break;
      case 'purchase_credit_adjustment':
        icon = Icons.arrow_downward;
        iconColor = Colors.blue.shade700;
        backgroundColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade200;
        amountText = '-\$${payment.paymentAmount.abs().toStringAsFixed(2)}';
        break;
      case 'purchase_cash_refund':
        icon = Icons.money_off;
        iconColor = Colors.orange.shade700;
        backgroundColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade200;
        amountText = 'Cash: -\$${payment.paymentAmount.abs().toStringAsFixed(2)}';
        break;
      default:
        icon = Icons.receipt;
        iconColor = Colors.grey.shade700;
        backgroundColor = Colors.grey.shade50;
        borderColor = Colors.grey.shade200;
        amountText = '\$${payment.paymentAmount.toStringAsFixed(2)}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: borderColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.description ?? _getDefaultDescription(payment.type),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  _formatDateTime(payment.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (payment.paymentMethod != null)
                  Text(
                    'Method: ${payment.paymentMethod}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountText,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
              Text(
                'Due: \$${payment.totalDue.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                'Balance: \$${payment.balance.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getDefaultDescription(String type) {
    switch (type) {
      case 'vendor_payment':
        return 'Payment Made to Vendor';
      case 'credit_purchase':
        return 'Credit Purchase';
      case 'purchase_credit_adjustment':
        return 'Purchase Return - Credit Adjustment';
      case 'purchase_cash_refund':
        return 'Purchase Return - Cash Refund';
      default:
        return 'Transaction';
    }
  }

  void _processPayment(PaymentProvider paymentProvider) async {
    final amount = double.tryParse(_paymentController.text);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid payment amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (amount > paymentProvider.vendorTotalDue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment amount cannot exceed total due'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text(
          'Make payment of \$${amount.toStringAsFixed(2)} to vendor via ${_paymentMethod.toUpperCase()}?\n\nRemaining due will be \$${(paymentProvider.vendorTotalDue - amount).toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _showLoadingDialog('Processing payment...');
      
      try {
        final success = await paymentProvider.processVendorPayment(
          _selectedVendorId!,
          amount,
          _paymentMethod,
        );

        _hideLoadingDialog();

        if (success && mounted) {
          _paymentController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment processed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          final errorMessage = paymentProvider.error != null 
              ? 'Failed to process payment: ${paymentProvider.error}'
              : 'Failed to process payment: Unknown error occurred';
              
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        _hideLoadingDialog();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unexpected error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }
}