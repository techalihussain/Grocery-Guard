import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sale_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/user_provider.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<SaleModel> _paymentHistory = [];
  UserModel? currentUser;
  bool _isLoading = true;
  String _selectedFilter = 'All';
  DateTimeRange? _selectedDateRange;

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
          _loadPaymentHistory();
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loadPaymentHistory() async {
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    await salesProvider.loadAllSales();
    
    if (mounted) {
      setState(() {
        // Get all completed transactions for this customer (representing payments made)
        var allTransactions = salesProvider.allSales
            .where((sale) => 
                sale.customerId == currentUser!.id &&
                sale.status == 'completed')
            .toList();

        // Apply filters
        _paymentHistory = _applyFilters(allTransactions);
        
        // Sort by date (newest first)
        _paymentHistory.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _isLoading = false;
      });
    }
  }

  List<SaleModel> _applyFilters(List<SaleModel> transactions) {
    var filtered = transactions;

    // Apply payment method filter
    if (_selectedFilter != 'All') {
      filtered = filtered.where((sale) {
        switch (_selectedFilter) {
          case 'Cash':
            return !sale.isCredit;
          case 'Credit':
            return sale.isCredit;
          case 'Purchases':
            return !sale.isReturn;
          case 'Returns':
            return sale.isReturn;
          default:
            return true;
        }
      }).toList();
    }

    // Apply date range filter
    if (_selectedDateRange != null) {
      filtered = filtered.where((sale) {
        return sale.createdAt.isAfter(
              _selectedDateRange!.start.subtract(const Duration(days: 1)),
            ) &&
            sale.createdAt.isBefore(
              _selectedDateRange!.end.add(const Duration(days: 1)),
            );
      }).toList();
    }

    return filtered;
  }

  double get totalCashPayments {
    return _paymentHistory
        .where((sale) => !sale.isCredit && !sale.isReturn)
        .fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  double get totalCreditTransactions {
    return _paymentHistory
        .where((sale) => sale.isCredit && !sale.isReturn)
        .fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  double get totalRefunds {
    return _paymentHistory
        .where((sale) => sale.isReturn)
        .fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPaymentHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummarySection(),
          _buildFiltersSection(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _paymentHistory.isEmpty
                    ? _buildEmptyState()
                    : _buildPaymentsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            spreadRadius: 1,
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
                  'Cash Payments',
                  '\$${totalCashPayments.toStringAsFixed(2)}',
                  Icons.money,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Credit Purchases',
                  '\$${totalCreditTransactions.toStringAsFixed(2)}',
                  Icons.credit_card,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Refunds',
                  '\$${totalRefunds.toStringAsFixed(2)}',
                  Icons.keyboard_return,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', _selectedFilter == 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('Cash', _selectedFilter == 'Cash'),
                const SizedBox(width: 8),
                _buildFilterChip('Credit', _selectedFilter == 'Credit'),
                const SizedBox(width: 8),
                _buildFilterChip('Purchases', _selectedFilter == 'Purchases'),
                const SizedBox(width: 8),
                _buildFilterChip('Returns', _selectedFilter == 'Returns'),
                const SizedBox(width: 8),
                _buildDateRangeChip(),
                const SizedBox(width: 8),
                if (_hasActiveFilters()) _buildClearFiltersChip(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? label : 'All';
        });
        _loadPaymentHistory();
      },
      selectedColor: Colors.green.shade100,
      checkmarkColor: Colors.green.shade700,
    );
  }

  Widget _buildDateRangeChip() {
    return ActionChip(
      label: Text(
        _selectedDateRange != null
            ? '${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}'
            : 'Date Range',
      ),
      avatar: Icon(
        Icons.date_range,
        size: 18,
        color: _selectedDateRange != null
            ? Colors.green.shade700
            : Colors.grey.shade600,
      ),
      onPressed: _selectDateRange,
      backgroundColor: _selectedDateRange != null
          ? Colors.green.shade100
          : Colors.grey.shade100,
    );
  }

  Widget _buildClearFiltersChip() {
    return ActionChip(
      label: const Text('Clear Filters'),
      avatar: const Icon(Icons.clear, size: 18),
      onPressed: _clearFilters,
      backgroundColor: Colors.orange.shade100,
    );
  }

  Widget _buildPaymentsList() {
    return RefreshIndicator(
      onRefresh: () async => _loadPaymentHistory(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _paymentHistory.length,
        itemBuilder: (context, index) {
          final payment = _paymentHistory[index];
          return _buildPaymentCard(payment);
        },
      ),
    );
  }

  Widget _buildPaymentCard(SaleModel payment) {
    final isRefund = payment.isReturn;
    final isCashPayment = !payment.isCredit;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showPaymentDetails(payment),
        borderRadius: BorderRadius.circular(12),
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
                            Icon(
                              isRefund 
                                  ? Icons.keyboard_return 
                                  : (isCashPayment ? Icons.money : Icons.credit_card),
                              color: isRefund 
                                  ? Colors.orange.shade600 
                                  : (isCashPayment ? Colors.green.shade600 : Colors.purple.shade600),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              payment.invoiceNo,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(payment.createdAt),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isRefund ? '+' : '-'}\$${payment.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isRefund ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'COMPLETED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      isRefund ? 'Refund' : 'Purchase',
                      isRefund ? Icons.keyboard_return : Icons.shopping_cart,
                      isRefund ? Colors.orange : Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoChip(
                      isCashPayment ? 'Cash Payment' : 'Credit Purchase',
                      isCashPayment ? Icons.money : Icons.credit_card,
                      isCashPayment ? Colors.green : Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
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
          Icon(Icons.payment_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Payment History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hasActiveFilters()
                ? 'No payments found for the selected filters'
                : 'Your payment history will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          if (_hasActiveFilters()) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _clearFilters,
              child: const Text('Clear Filters'),
            ),
          ],
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
            _buildDetailRow('Date & Time', _formatDateTime(payment.createdAt)),
            _buildDetailRow('Transaction Type', payment.isReturn ? 'Refund' : 'Purchase'),
            _buildDetailRow('Amount', '\$${payment.totalAmount.toStringAsFixed(2)}'),
            _buildDetailRow('Payment Method', payment.isCredit ? 'Credit' : 'Cash'),
            _buildDetailRow('Status', 'COMPLETED'),
            if (payment.subtotals != null)
              _buildDetailRow('Subtotal', '\$${payment.subtotals!.toStringAsFixed(2)}'),
            if (payment.discount != null && payment.discount! > 0)
              _buildDetailRow('Discount', '-\$${payment.discount!.toStringAsFixed(2)}'),
            if (payment.tax != null && payment.tax! > 0)
              _buildDetailRow('Tax', '\$${payment.tax!.toStringAsFixed(2)}'),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      payment.isReturn 
                          ? 'Refund processed successfully'
                          : payment.isCredit 
                              ? 'Credit purchase completed'
                              : 'Payment processed successfully',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 14,
                      ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Payment History'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Transaction Type:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'All',
                'Cash',
                'Credit',
                'Purchases',
                'Returns',
              ].map((filter) {
                return FilterChip(
                  label: Text(filter),
                  selected: _selectedFilter == filter,
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = selected ? filter : 'All';
                    });
                  },
                  selectedColor: Colors.green.shade100,
                  checkmarkColor: Colors.green.shade700,
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadPaymentHistory();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _loadPaymentHistory();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedFilter = 'All';
      _selectedDateRange = null;
    });
    _loadPaymentHistory();
  }

  bool _hasActiveFilters() {
    return _selectedFilter != 'All' || _selectedDateRange != null;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}