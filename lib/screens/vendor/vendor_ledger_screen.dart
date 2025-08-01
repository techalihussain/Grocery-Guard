import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/payment_provider.dart';
import '../../models/payment_model.dart';

class VendorLedgerScreen extends StatefulWidget {
  final String vendorId;

  const VendorLedgerScreen({super.key, required this.vendorId});

  @override
  State<VendorLedgerScreen> createState() => _VendorLedgerScreenState();
}

class _VendorLedgerScreenState extends State<VendorLedgerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
    await paymentProvider.loadVendorData(widget.vendorId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Sale Ledger',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<PaymentProvider>(
        builder: (context, paymentProvider, child) {
          if (paymentProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (paymentProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading ledger',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    paymentProvider.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final vendorPayments = paymentProvider.vendorPayments;
          final totalBalance = paymentProvider.vendorTotalBalance;
          final totalPaid = paymentProvider.vendorTotalPaid;
          final totalDue = paymentProvider.vendorTotalDue;

          return Column(
            children: [
              // Balance Summary
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.orange[600]!,
                      Colors.orange[400]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.3),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Account Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildBalanceItem(
                            'Total Balance',
                            '\$${totalBalance.toStringAsFixed(2)}',
                            Icons.account_balance_wallet,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        Expanded(
                          child: _buildBalanceItem(
                            'Amount Due',
                            '\$${totalDue.toStringAsFixed(2)}',
                            Icons.payment,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildBalanceItem(
                            'Total Paid',
                            '\$${totalPaid.toStringAsFixed(2)}',
                            Icons.check_circle,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        Expanded(
                          child: _buildBalanceItem(
                            'Transactions',
                            vendorPayments.length.toString(),
                            Icons.receipt_long,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Transaction History
              Expanded(
                child: vendorPayments.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No transactions found',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Your transaction history will appear here',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: vendorPayments.length,
                        itemBuilder: (context, index) {
                          final payment = vendorPayments[index];
                          return _buildTransactionCard(payment);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBalanceItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTransactionCard(PaymentModel payment) {
    final isCredit = payment.paymentAmount > 0;
    final transactionColor = isCredit ? Colors.green : Colors.red;
    final transactionIcon = isCredit ? Icons.add_circle : Icons.remove_circle;
    final transactionType = _getTransactionType(payment.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: transactionColor.withValues(alpha: 0.2),
          child: Icon(
            transactionIcon,
            color: transactionColor,
            size: 20,
          ),
        ),
        title: Text(
          transactionType,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMM dd, yyyy • HH:mm').format(payment.createdAt)),
            if (payment.referenceId.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Ref: ${payment.referenceId}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
            if (payment.paymentMethod != null) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  payment.paymentMethod!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isCredit ? '+' : '-'}\$${payment.paymentAmount.abs().toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: transactionColor,
              ),
            ),
            Text(
              'Balance: \$${payment.balance.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  String _getTransactionType(String type) {
    switch (type) {
      case 'credit_purchase':
        return 'Credit Purchase';
      case 'payment_received':
        return 'Payment Received';
      case 'purchase_return':
        return 'Purchase Return';
      case 'credit_adjustment':
        return 'Credit Adjustment';
      case 'cash_refund':
        return 'Cash Refund';
      default:
        return type.replaceAll('_', ' ').split(' ')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }
}