import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/payment_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../models/payment_model.dart';
import '../../models/purchase_model.dart';

class VendorDuePaymentsScreen extends StatefulWidget {
  final String vendorId;

  const VendorDuePaymentsScreen({super.key, required this.vendorId});

  @override
  State<VendorDuePaymentsScreen> createState() => _VendorDuePaymentsScreenState();
}

class _VendorDuePaymentsScreenState extends State<VendorDuePaymentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
    final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
    
    await Future.wait([
      paymentProvider.loadVendorData(widget.vendorId),
      purchaseProvider.loadAllPurchases(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Due Payments',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer2<PaymentProvider, PurchaseProvider>(
        builder: (context, paymentProvider, purchaseProvider, child) {
          if (paymentProvider.isLoading || purchaseProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (paymentProvider.error != null || purchaseProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading payment data',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    paymentProvider.error ?? purchaseProvider.error ?? '',
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

          final totalDue = paymentProvider.vendorTotalDue;
          final totalBalance = paymentProvider.vendorTotalBalance;
          
          // Get unpaid credit purchases
          final unpaidPurchases = purchaseProvider.allPurchases
              .where((purchase) => 
                  purchase.vendorId == widget.vendorId &&
                  purchase.isCredit &&
                  purchase.status == 'completed' &&
                  !purchase.isReturn)
              .toList();

          // Sort by date (oldest first for payment priority)
          unpaidPurchases.sort((a, b) => a.createdAt.compareTo(b.createdAt));

          // Get recent payments for context
          final recentPayments = paymentProvider.vendorPayments
              .where((payment) => payment.type == 'payment_received')
              .take(5)
              .toList();

          return Column(
            children: [
              // Due Amount Summary
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.red[600]!,
                      Colors.red[400]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.3),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Payment Summary',
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
                          child: _buildSummaryItem(
                            'Amount Due',
                            '\$${totalDue.toStringAsFixed(2)}',
                            Icons.payment,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        Expanded(
                          child: _buildSummaryItem(
                            'Total Balance',
                            '\$${totalBalance.toStringAsFixed(2)}',
                            Icons.account_balance_wallet,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryItem(
                            'Unpaid Orders',
                            unpaidPurchases.length.toString(),
                            Icons.receipt,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        Expanded(
                          child: _buildSummaryItem(
                            'Status',
                            totalDue > 0 ? 'PENDING' : 'PAID',
                            totalDue > 0 ? Icons.warning : Icons.check_circle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Tabs for Unpaid Orders and Recent Payments
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TabBar(
                          labelColor: Colors.red[600],
                          unselectedLabelColor: Colors.grey[600],
                          indicatorColor: Colors.red[600],
                          tabs: const [
                            Tab(text: 'Unpaid Orders'),
                            Tab(text: 'Recent Payments'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Unpaid Orders Tab
                            unpaidPurchases.isEmpty
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle, size: 64, color: Colors.green),
                                        SizedBox(height: 16),
                                        Text(
                                          'All payments are up to date!',
                                          style: TextStyle(fontSize: 18, color: Colors.green),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'No outstanding payments found',
                                          style: TextStyle(fontSize: 14, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: unpaidPurchases.length,
                                    itemBuilder: (context, index) {
                                      final purchase = unpaidPurchases[index];
                                      return _buildUnpaidOrderCard(purchase);
                                    },
                                  ),
                            // Recent Payments Tab
                            recentPayments.isEmpty
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.payment, size: 64, color: Colors.grey),
                                        SizedBox(height: 16),
                                        Text(
                                          'No recent payments',
                                          style: TextStyle(fontSize: 18, color: Colors.grey),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Payment history will appear here',
                                          style: TextStyle(fontSize: 14, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: recentPayments.length,
                                    itemBuilder: (context, index) {
                                      final payment = recentPayments[index];
                                      return _buildPaymentCard(payment);
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon) {
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

  Widget _buildUnpaidOrderCard(PurchaseModel purchase) {
    final daysSinceOrder = DateTime.now().difference(purchase.createdAt).inDays;
    final urgencyColor = daysSinceOrder > 30 ? Colors.red : 
                        daysSinceOrder > 15 ? Colors.orange : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: urgencyColor.withValues(alpha: 0.2),
          child: Icon(
            Icons.receipt,
            color: urgencyColor,
            size: 20,
          ),
        ),
        title: Text(
          'Order #${purchase.invoiceNo}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMM dd, yyyy').format(purchase.createdAt)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: urgencyColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$daysSinceOrder days ago',
                    style: TextStyle(
                      fontSize: 10,
                      color: urgencyColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  purchase.paymentMethod.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${purchase.totalAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: urgencyColor,
              ),
            ),
            Text(
              'DUE',
              style: TextStyle(
                fontSize: 12,
                color: urgencyColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildPaymentCard(PaymentModel payment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withValues(alpha: 0.2),
          child: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 20,
          ),
        ),
        title: const Text(
          'Payment Received',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMM dd, yyyy • HH:mm').format(payment.createdAt)),
            if (payment.paymentMethod != null) ...[
              const SizedBox(height: 4),
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
              '+\$${payment.paymentAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            Text(
              'PAID',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}