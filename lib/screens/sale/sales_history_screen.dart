import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sale_model.dart';
import '../../models/sale_purchase_item_model.dart';
import '../../providers/sales_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/product_provider.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SaleModel> _filteredSales = [];
  List<SaleModel> _allSales = [];
  String _selectedFilter = 'All';
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSalesHistory();
    });
  }

  void _loadSalesHistory() async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    // Load all sales (completed, drafted, returns)
    await salesProvider.loadAllSales();
    if (mounted) {
      setState(() {
        _allSales = salesProvider.allSales;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    List<SaleModel> filtered = List.from(_allSales);

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
        title: const Text('Sales History'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSalesHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(
            child: Consumer<SalesProvider>(
              builder: (context, salesProvider, child) {
                if (salesProvider.isLoading && _allSales.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (salesProvider.error != null && _allSales.isEmpty) {
                  return _buildErrorState(salesProvider.error!);
                }

                if (_filteredSales.isEmpty && _allSales.isEmpty) {
                  return _buildEmptyState();
                }

                if (_filteredSales.isEmpty && _allSales.isNotEmpty) {
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
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue.shade700,
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
            ? Colors.blue.shade700
            : Colors.grey.shade600,
      ),
      onPressed: _selectDateRange,
      backgroundColor: _selectedDateRange != null
          ? Colors.blue.shade100
          : Colors.grey.shade100,
    );
  }

  Widget _buildClearFiltersChip() {
    return ActionChip(
      label: const Text('Clear Filters'),
      avatar: const Icon(Icons.clear, size: 18),
      onPressed: _clearFilters,
      backgroundColor: Colors.red.shade100,
    );
  }

  Widget _buildSalesList() {
    return RefreshIndicator(
      onRefresh: () async => _loadSalesHistory(),
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
                            color: Colors.blue,
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
            'Error loading sales history',
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
            onPressed: _loadSalesHistory,
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
          Icon(Icons.history, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Sales History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete some sales to see them here',
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
              backgroundColor: Colors.green,
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
        title: const Text('Filter Sales'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Status & Payment:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  [
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
                      selectedColor: Colors.blue.shade100,
                      checkmarkColor: Colors.blue.shade700,
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

class SaleDetailsSheet extends StatefulWidget {
  final SaleModel sale;

  const SaleDetailsSheet({super.key, required this.sale});

  @override
  State<SaleDetailsSheet> createState() => _SaleDetailsSheetState();
}

class _SaleDetailsSheetState extends State<SaleDetailsSheet> {
  String? customerName;
  bool isLoadingCustomer = true;
  List<ItemModel> saleItems = [];
  bool isLoadingItems = true;

  @override
  void initState() {
    super.initState();
    _loadCustomerName();
    _loadSaleItems();
  }

  Future<void> _loadCustomerName() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final customer = await userProvider.getUserByIdSilent(
        widget.sale.customerId,
      );

      if (mounted) {
        setState(() {
          customerName = customer?.name ?? 'Unknown Customer';
          isLoadingCustomer = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          customerName = 'Unknown Customer';
          isLoadingCustomer = false;
        });
      }
    }
  }

  Future<void> _loadSaleItems() async {
    try {
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      final items = await salesProvider.getSaleItems(widget.sale.id);

      if (mounted) {
        setState(() {
          saleItems = items;
          isLoadingItems = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          saleItems = [];
          isLoadingItems = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
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

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.sale.invoiceNo,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Sale Details',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.sale.status == 'completed'
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.sale.status == 'completed'
                        ? Colors.green.shade300
                        : Colors.orange.shade300,
                  ),
                ),
                child: Text(
                  widget.sale.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: widget.sale.status == 'completed'
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Sale Information
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection('Sale Information', [
                    _buildDetailRow('Invoice Number', widget.sale.invoiceNo),
                    _buildDetailRow(
                      'Created Date',
                      _formatDateTime(widget.sale.createdAt),
                    ),
                    _buildDetailRow(
                      'Payment Method',
                      widget.sale.isCredit ? 'Credit' : 'Cash',
                    ),
                    _buildDetailRow(
                      'Customer',
                      isLoadingCustomer
                          ? 'Loading...'
                          : (customerName ?? 'Unknown Customer'),
                    ),
                    if (widget.sale.isReturn)
                      _buildDetailRow('Type', 'RETURN', isHighlight: true),
                  ]),
                  const SizedBox(height: 20),

                  _buildItemsSection(),
                  const SizedBox(height: 20),

                  _buildDetailSection('Amount Breakdown', [
                    _buildDetailRow(
                      'Subtotal',
                      '\$${(widget.sale.subtotals ?? 0.0).toStringAsFixed(2)}',
                    ),
                    _buildDetailRow(
                      'Discount',
                      '-\$${(widget.sale.discount ?? 0.0).toStringAsFixed(2)}',
                    ),
                    _buildDetailRow(
                      'Tax',
                      '\$${(widget.sale.tax ?? 0.0).toStringAsFixed(2)}',
                    ),
                    _buildDetailRow(
                      'Total Amount',
                      '\$${widget.sale.totalAmount.toStringAsFixed(2)}',
                      isTotal: true,
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isTotal = false,
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black : Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal
                  ? Colors.green.shade700
                  : isHighlight
                  ? Colors.red.shade700
                  : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Items Sold',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: isLoadingItems
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              : saleItems.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No items found',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: saleItems.map((item) => _buildItemRow(item)).toList(),
                    ),
        ),
      ],
    );
  }

  Widget _buildItemRow(ItemModel item) {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final product = productProvider.getProductFromList(item.productId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          // Product info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product?.name ?? 'Unknown Product',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unit: ${item.unit}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          // Quantity
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Qty',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Unit Price
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Price',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  '\$${item.unitPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Total
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  '\$${item.totalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
