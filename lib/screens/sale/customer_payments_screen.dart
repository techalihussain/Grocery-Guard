import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/payment_model.dart';
import '../../providers/payment_provider.dart';
import '../../providers/sales_provider.dart';

class CustomerPaymentsScreen extends StatefulWidget {
  const CustomerPaymentsScreen({super.key});

  @override
  State<CustomerPaymentsScreen> createState() => _CustomerPaymentsScreenState();
}

class _CustomerPaymentsScreenState extends State<CustomerPaymentsScreen> {
  String? _selectedCustomerId;
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
      _loadCustomers();
    });
  }

  void _loadCustomers() async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    try {
      await salesProvider.loadCustomers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load customers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _loadCustomerData(String customerId) async {
    _showLoadingDialog('Loading customer data...');
    
    try {
      final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
      await paymentProvider.loadCustomerData(customerId);
      _hideLoadingDialog();
    } catch (e) {
      _hideLoadingDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load customer data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesProvider = Provider.of<SalesProvider>(context);
    final paymentProvider = Provider.of<PaymentProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Payments'),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_selectedCustomerId != null) {
                _loadCustomerData(_selectedCustomerId!);
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
            _buildCustomerSelection(salesProvider),
            const SizedBox(height: 20),
            if (_selectedCustomerId != null) ...[
              _buildCustomerSummary(paymentProvider),
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

  Widget _buildCustomerSelection(SalesProvider salesProvider) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Customer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCustomerId,
              decoration: const InputDecoration(
                labelText: 'Customer',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              items: salesProvider.customers.map((customer) {
                return DropdownMenuItem(
                  value: customer.id,
                  child: SizedBox(
                    width: screenWidth * 0.5,
                    child: Text(
                      '${customer.name} - ${customer.phoneNumber}',
                      style: const TextStyle(overflow: TextOverflow.ellipsis),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCustomerId = value;
                });
                if (value != null) {
                  _loadCustomerData(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSummary(PaymentProvider paymentProvider) {
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
                          'Total Outstanding',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '\$${paymentProvider.customerTotalDue.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: paymentProvider.customerTotalDue > 0
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
                                    '\$${paymentProvider.customerTotalBalance.toStringAsFixed(2)}',
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
                                    '\$${paymentProvider.customerTotalPaid.toStringAsFixed(2)}',
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
              'Process Payment',
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
                  'bank',
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
                onPressed: paymentProvider.customerTotalDue > 0
                    ? () => _processPayment(paymentProvider)
                    : null,
                icon: const Icon(Icons.payment),
                label: const Text('Process Payment'),
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
            else if (paymentProvider.customerPayments.isEmpty)
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
                itemCount: paymentProvider.customerPayments.length,
                itemBuilder: (context, index) {
                  final payment = paymentProvider.customerPayments[index];
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
      case 'payment':
        icon = Icons.arrow_downward;
        iconColor = Colors.green.shade700;
        backgroundColor = Colors.green.shade50;
        borderColor = Colors.green.shade200;
        amountText = '+\$${payment.paymentAmount.toStringAsFixed(2)}';
        break;
      case 'credit_sale':
        icon = Icons.shopping_cart;
        iconColor = Colors.red.shade700;
        backgroundColor = Colors.red.shade50;
        borderColor = Colors.red.shade200;
        amountText = '+\$${payment.paymentAmount.toStringAsFixed(2)}';
        break;
      case 'credit_adjustment':
        icon = Icons.arrow_upward;
        iconColor = Colors.blue.shade700;
        backgroundColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade200;
        amountText = '-\$${payment.paymentAmount.abs().toStringAsFixed(2)}';
        break;
      case 'cash_refund':
        // Cash refunds don't affect the credit balance, so we show them differently
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
      case 'payment':
        return 'Payment Received';
      case 'credit_sale':
        return 'Credit Sale';
      case 'credit_adjustment':
        return 'Return - Credit Adjustment';
      case 'cash_refund':
        return 'Return - Cash Refund';
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

    if (amount > paymentProvider.customerTotalDue) {
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
          'Process payment of \$${amount.toStringAsFixed(2)} via ${_paymentMethod.toUpperCase()}?\n\nRemaining due will be \$${(paymentProvider.customerTotalDue - amount).toStringAsFixed(2)}',
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
        final success = await paymentProvider.processCustomerPayment(
          _selectedCustomerId!,
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