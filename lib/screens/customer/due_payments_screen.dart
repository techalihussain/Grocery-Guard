import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sale_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/user_provider.dart';

class DuePaymentsScreen extends StatefulWidget {
  const DuePaymentsScreen({super.key});

  @override
  State<DuePaymentsScreen> createState() => _DuePaymentsScreenState();
}

class _DuePaymentsScreenState extends State<DuePaymentsScreen> {
  List<SaleModel> _duePayments = [];
  UserModel? currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentUser();
    });
  }

  Future<void> _loadCurrentUser() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (authProvider.user != null) {
      try {
        var user = await userProvider.getUserById(authProvider.user!.uid);
        if (user == null && authProvider.user!.email != null) {
          user = await userProvider.getUserByEmail(authProvider.user!.email!);
        }

        if (mounted) {
          setState(() {
            currentUser = user;
          });
          _loadDuePayments();
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loadDuePayments() async {
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    await salesProvider.loadAllSales();
    
    if (mounted) {
      setState(() {
        // Filter to show only credit purchases that are completed (due for payment)
        _duePayments = salesProvider.allSales
            .where((sale) => 
                sale.customerId == currentUser!.id &&
                sale.isCredit &&
                sale.status == 'completed' &&
                !sale.isReturn)
            .toList();
        
        // Sort by date (oldest first - most urgent)
        _duePayments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _isLoading = false;
      });
    }
  }

  double get totalDueAmount {
    return _duePayments.fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Due Payments'),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDuePayments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCard(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _duePayments.isEmpty
                    ? _buildEmptyState()
                    : _buildDuePaymentsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade400, Colors.red.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Outstanding Balance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${totalDueAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_duePayments.length} pending payment${_duePayments.length != 1 ? 's' : ''}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuePaymentsList() {
    return RefreshIndicator(
      onRefresh: () async => _loadDuePayments(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _duePayments.length,
        itemBuilder: (context, index) {
          final payment = _duePayments[index];
          return _buildPaymentCard(payment, index);
        },
      ),
    );
  }

  Widget _buildPaymentCard(SaleModel payment, int index) {
    final daysSincePurchase = DateTime.now().difference(payment.createdAt).inDays;
    final isOverdue = daysSincePurchase > 30; // Consider overdue after 30 days
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showPaymentDetails(payment),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isOverdue 
                ? Border.all(color: Colors.red.shade300, width: 2)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                payment.invoiceNo,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              if (isOverdue) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'OVERDUE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Purchase Date: ${_formatDate(payment.createdAt)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '$daysSincePurchase days ago',
                            style: TextStyle(
                              fontSize: 12,
                              color: isOverdue ? Colors.red.shade600 : Colors.grey.shade500,
                              fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${payment.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isOverdue ? Colors.red.shade700 : Colors.green.shade700,
                          ),
                        ),
                        Text(
                          'Due Amount',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        'Credit Purchase',
                        Icons.credit_card,
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoChip(
                        isOverdue ? 'Overdue' : 'Pending',
                        isOverdue ? Icons.warning : Icons.schedule,
                        isOverdue ? Colors.red : Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showPaymentOptions(payment),
                    icon: const Icon(Icons.payment, size: 18),
                    label: const Text('Make Payment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade400),
          const SizedBox(height: 16),
          Text(
            'No Due Payments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have no outstanding payments at this time',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Text(
            '🎉 Great job staying on top of your payments!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDetails(SaleModel payment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Payment Details',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildDetailRow('Invoice Number', payment.invoiceNo),
            _buildDetailRow('Purchase Date', _formatDate(payment.createdAt)),
            _buildDetailRow('Amount Due', '\$${payment.totalAmount.toStringAsFixed(2)}'),
            _buildDetailRow('Payment Method', 'Credit'),
            _buildDetailRow('Status', 'Pending Payment'),
            const SizedBox(height: 20),
            const Text(
              'Payment Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Contact the store to make your payment or arrange a payment plan.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentOptions(SaleModel payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invoice: ${payment.invoiceNo}'),
            Text('Amount: \$${payment.totalAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const Text(
              'To make a payment, please contact the store directly or visit in person.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Here you could add functionality to contact the store
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Contact store for payment processing'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            child: const Text('Contact Store'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}