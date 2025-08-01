import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sale_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/user_provider.dart';

class PurchaseLedgerScreen extends StatefulWidget {
  const PurchaseLedgerScreen({super.key});

  @override
  State<PurchaseLedgerScreen> createState() => _PurchaseLedgerScreenState();
}

class _PurchaseLedgerScreenState extends State<PurchaseLedgerScreen> {
  List<SaleModel> _allTransactions = [];
  UserModel? currentUser;
  bool _isLoading = true;
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
          _loadLedgerData();
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loadLedgerData() async {
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    await salesProvider.loadAllSales();
    
    if (mounted) {
      setState(() {
        // Get all transactions for this customer
        _allTransactions = salesProvider.allSales
            .where((sale) => sale.customerId == currentUser!.id)
            .toList();
        
        // Apply date filter if selected
        if (_selectedDateRange != null) {
          _allTransactions = _allTransactions.where((sale) {
            return sale.createdAt.isAfter(
                  _selectedDateRange!.start.subtract(const Duration(days: 1)),
                ) &&
                sale.createdAt.isBefore(
                  _selectedDateRange!.end.add(const Duration(days: 1)),
                );
          }).toList();
        }
        
        // Sort by date (newest first)
        _allTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _isLoading = false;
      });
    }
  }

  double get totalPurchases {
    return _allTransactions
        .where((sale) => !sale.isReturn)
        .fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  double get totalReturns {
    return _allTransactions
        .where((sale) => sale.isReturn)
        .fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  double get netAmount {
    return totalPurchases - totalReturns;
  }

  double get outstandingBalance {
    return _allTransactions
        .where((sale) => sale.isCredit && !sale.isReturn && sale.status == 'completed')
        .fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Ledger'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Filter by Date',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLedgerData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummarySection(),
          if (_selectedDateRange != null) _buildDateRangeChip(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allTransactions.isEmpty
                    ? _buildEmptyState()
                    : _buildLedgerList(),
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
          colors: [Colors.orange.shade400, Colors.orange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Account Summary',
            style: const TextStyle(
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
                  'Total Purchases',
                  '\$${totalPurchases.toStringAsFixed(2)}',
                  Icons.shopping_cart,
                  Colors.white,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Total Returns',
                  '\$${totalReturns.toStringAsFixed(2)}',
                  Icons.keyboard_return,
                  Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Net Amount',
                  '\$${netAmount.toStringAsFixed(2)}',
                  Icons.account_balance,
                  Colors.white,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Outstanding',
                  '\$${outstandingBalance.toStringAsFixed(2)}',
                  Icons.pending_actions,
                  outstandingBalance > 0 ? Colors.yellow.shade200 : Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color textColor) {
    return Column(
      children: [
        Icon(icon, color: textColor, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.8),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDateRangeChip() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.date_range, color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Filtered: ${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedDateRange = null;
                      });
                      _loadLedgerData();
                    },
                    icon: Icon(Icons.clear, color: Colors.orange.shade700, size: 18),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerList() {
    return RefreshIndicator(
      onRefresh: () async => _loadLedgerData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allTransactions.length,
        itemBuilder: (context, index) {
          final transaction = _allTransactions[index];
          return _buildLedgerEntry(transaction);
        },
      ),
    );
  }

  Widget _buildLedgerEntry(SaleModel transaction) {
    final isDebit = !transaction.isReturn; // Purchase is debit, return is credit
    final amount = transaction.totalAmount;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _showTransactionDetails(transaction),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Date and Invoice
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(transaction.createdAt),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      transaction.invoiceNo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Description
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.isReturn ? 'Purchase Return' : 'Purchase',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          transaction.isCredit ? Icons.credit_card : Icons.money,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          transaction.isCredit ? 'Credit' : 'Cash',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (transaction.status != 'completed') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              transaction.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Amount columns
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Debit column
                    SizedBox(
                      width: 60,
                      child: Text(
                        isDebit ? '\$${amount.toStringAsFixed(2)}' : '-',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDebit ? Colors.red.shade600 : Colors.grey.shade400,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Credit column
                    SizedBox(
                      width: 60,
                      child: Text(
                        !isDebit ? '\$${amount.toStringAsFixed(2)}' : '-',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: !isDebit ? Colors.green.shade600 : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Transactions Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedDateRange != null
                ? 'No transactions found for the selected date range'
                : 'Your purchase ledger will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          if (_selectedDateRange != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedDateRange = null;
                });
                _loadLedgerData();
              },
              child: const Text('Clear Date Filter'),
            ),
          ],
        ],
      ),
    );
  }

  void _showTransactionDetails(SaleModel transaction) {
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
              'Transaction Details',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildDetailRow('Invoice Number', transaction.invoiceNo),
            _buildDetailRow('Date', _formatDateTime(transaction.createdAt)),
            _buildDetailRow('Type', transaction.isReturn ? 'Purchase Return' : 'Purchase'),
            _buildDetailRow('Amount', '\$${transaction.totalAmount.toStringAsFixed(2)}'),
            _buildDetailRow('Payment Method', transaction.isCredit ? 'Credit' : 'Cash'),
            _buildDetailRow('Status', transaction.status.toUpperCase()),
            if (transaction.subtotals != null)
              _buildDetailRow('Subtotal', '\$${transaction.subtotals!.toStringAsFixed(2)}'),
            if (transaction.discount != null && transaction.discount! > 0)
              _buildDetailRow('Discount', '-\$${transaction.discount!.toStringAsFixed(2)}'),
            if (transaction.tax != null && transaction.tax! > 0)
              _buildDetailRow('Tax', '\$${transaction.tax!.toStringAsFixed(2)}'),
            const SizedBox(height: 20),
            if (transaction.isCredit && transaction.status == 'completed' && !transaction.isReturn)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is a credit purchase. Payment is still pending.',
                        style: TextStyle(
                          color: Colors.orange.shade700,
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
      _loadLedgerData();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}