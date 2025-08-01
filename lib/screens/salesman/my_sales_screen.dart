import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sale_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/user_provider.dart';
import '../sale/sales_history_screen.dart';

class MySalesScreen extends StatefulWidget {
  const MySalesScreen({super.key});

  @override
  State<MySalesScreen> createState() => _MySalesScreenState();
}

class _MySalesScreenState extends State<MySalesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SaleModel> _filteredSales = [];
  List<SaleModel> _mySales = [];
  String _selectedFilter = 'All';
  DateTimeRange? _selectedDateRange;
  UserModel? currentUser;

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
          _loadMySales();
        }
      } catch (e) {
        // Handle error silently
      }
    }
  }

  void _loadMySales() async {
    if (currentUser == null) return;

    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    await salesProvider.loadAllSales();
    
    if (mounted) {
      setState(() {
        // Filter sales to show only current user's sales
        _mySales = salesProvider.allSales
            .where((sale) => sale.createdBy == currentUser!.id)
            .toList();
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    List<SaleModel> filtered = List.from(_mySales);

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      filtered = filtered.where((sale) {
        return sale.invoiceNo.toLowerCase().contains(searchTerm) ||
            sale.customerId.toLowerCase().contains(searchTerm);
      }).toList();
    }

    // Apply status/payment method filter
    if (_selectedFilter != 'All') {
      filtered = filtered.where((sale) {
        switch (_selectedFilter) {
          case 'Cash':
            return !sale.isCredit && !sale.isReturn;
          case 'Credit':
            return sale.isCredit && !sale.isReturn;
          case 'Completed':
            return sale.status == 'completed' && !sale.isReturn;
          case 'Draft':
            return sale.status == 'drafted';
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

    // Sort by date (newest first)
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    setState(() {
      _filteredSales = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Sales - ${currentUser?.name ?? 'Loading...'}'),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMySales,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          _buildStatsCard(),
          Expanded(
            child: Consumer<SalesProvider>(
              builder: (context, salesProvider, child) {
                if (salesProvider.isLoading && _mySales.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (salesProvider.error != null && _mySales.isEmpty) {
                  return _buildErrorState(salesProvider.error!);
                }

                if (_filteredSales.isEmpty && _mySales.isEmpty) {
                  return _buildEmptyState();
                }

                if (_filteredSales.isEmpty && _mySales.isNotEmpty) {
                  return _buildNoResultsState();
                }

                return _buildSalesList();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    if (_mySales.isEmpty) return const SizedBox.shrink();

    final totalSales = _mySales.where((sale) => !sale.isReturn).length;
    final totalAmount = _mySales
        .where((sale) => !sale.isReturn && sale.status == 'completed')
        .fold(0.0, (sum, sale) => sum + sale.totalAmount);
    final totalReturns = _mySales.where((sale) => sale.isReturn).length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
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
          Text(
            'My Sales Summary',
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
                child: _buildStatItem(
                  'Total Sales',
                  totalSales.toString(),
                  Icons.shopping_cart,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Total Amount',
                  '\$${totalAmount.toStringAsFixed(2)}',
                  Icons.attach_money,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Returns',
                  totalReturns.toString(),
                  Icons.keyboard_return,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
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

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by invoice number or customer...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            onChanged: (value) => _applyFilters(),
          ),
          const SizedBox(height: 12),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', _selectedFilter == 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('Completed', _selectedFilter == 'Completed'),
                const SizedBox(width: 8),
                _buildFilterChip('Draft', _selectedFilter == 'Draft'),
                const SizedBox(width: 8),
                _buildFilterChip('Cash', _selectedFilter == 'Cash'),
                const SizedBox(width: 8),
                _buildFilterChip('Credit', _selectedFilter == 'Credit'),
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
        _applyFilters();
      },
      selectedColor: Colors.red.shade100,
      checkmarkColor: Colors.red.shade700,
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
            ? Colors.red.shade700
            : Colors.grey.shade600,
      ),
      onPressed: _selectDateRange,
      backgroundColor: _selectedDateRange != null
          ? Colors.red.shade100
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

  Widget _buildSalesList() {
    return RefreshIndicator(
      onRefresh: () async => _loadMySales(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredSales.length,
        itemBuilder: (context, index) {
          final sale = _filteredSales[index];
          return _buildSaleCard(sale);
        },
      ),
    );
  }

  Widget _buildSaleCard(SaleModel sale) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showSaleDetails(sale),
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
                        Text(
                          sale.invoiceNo,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(sale.createdAt),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: sale.status == 'completed'
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sale.status == 'completed'
                            ? Colors.green.shade300
                            : Colors.orange.shade300,
                      ),
                    ),
                    child: Text(
                      sale.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: sale.status == 'completed'
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      'Total Amount',
                      '\$${sale.totalAmount.toStringAsFixed(2)}',
                      Icons.attach_money,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInfoItem(
                      'Payment',
                      sale.isCredit ? 'Credit' : 'Cash',
                      sale.isCredit ? Icons.credit_card : Icons.money,
                      sale.isCredit ? Colors.purple : Colors.blue,
                    ),
                  ),
                ],
              ),
              if (sale.isReturn) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_return,
                        size: 16,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'RETURN',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            'Error loading your sales',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadMySales,
            child: const Text('Retry'),
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
          Icon(Icons.person_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Sales Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start making sales to see them here',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/add-sale');
            },
            icon: const Icon(Icons.add),
            label: const Text('Create New Sale'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Results Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _clearFilters,
            child: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }

  void _showSaleDetails(SaleModel sale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SaleDetailsSheet(sale: sale),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter My Sales'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Status & Payment:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'All',
                'Completed',
                'Draft',
                'Cash',
                'Credit',
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
                  selectedColor: Colors.red.shade100,
                  checkmarkColor: Colors.red.shade700,
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
              _applyFilters();
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
      _applyFilters();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedFilter = 'All';
      _selectedDateRange = null;
      _searchController.clear();
    });
    _applyFilters();
  }

  bool _hasActiveFilters() {
    return _selectedFilter != 'All' ||
        _selectedDateRange != null ||
        _searchController.text.isNotEmpty;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}