import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/purchase_model.dart';
import '../../models/sale_purchase_item_model.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/user_provider.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PurchaseModel> _filteredPurchases = [];
  String _selectedFilter = 'all'; // all, completed, returns

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPurchaseHistory();
    });
    _searchController.addListener(_filterPurchases);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadPurchaseHistory() async {
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );
    await purchaseProvider.loadAllPurchases();
    _filterPurchases();
  }

  void _filterPurchases() {
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredPurchases = purchaseProvider.allPurchases.where((purchase) {
        // Filter by search query
        final matchesSearch =
            query.isEmpty ||
            purchase.invoiceNo.toLowerCase().contains(query) ||
            purchase.vendorId.toLowerCase().contains(query);

        // Filter by status
        final matchesFilter =
            _selectedFilter == 'all' ||
            (_selectedFilter == 'completed' &&
                purchase.status == 'completed' &&
                !purchase.isReturn) ||
            (_selectedFilter == 'returns' && purchase.isReturn);

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase History'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPurchaseHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<PurchaseProvider>(
        builder: (context, purchaseProvider, child) {
          if (purchaseProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (purchaseProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading purchase history',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    purchaseProvider.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadPurchaseHistory,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Search and Filter Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search purchases...',
                        hintText: 'Invoice number, vendor...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All', 'all'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Completed', 'completed'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Returns', 'returns'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Purchase List
              Expanded(
                child: _filteredPurchases.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async => _loadPurchaseHistory(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredPurchases.length,
                          itemBuilder: (context, index) {
                            final purchase = _filteredPurchases[index];
                            return _buildPurchaseCard(purchase);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
        _filterPurchases();
      },
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue.shade700,
    );
  }

  Widget _buildEmptyState() {
    String message;
    String subtitle;
    IconData icon;

    switch (_selectedFilter) {
      case 'completed':
        icon = Icons.check_circle_outline;
        message = 'No Completed Purchases';
        subtitle = 'Completed purchases will appear here';
        break;
      case 'returns':
        icon = Icons.keyboard_return;
        message = 'No Purchase Returns';
        subtitle = 'Purchase returns will appear here';
        break;
      default:
        icon = Icons.history;
        message = 'No Purchase History';
        subtitle = 'Your purchase history will appear here';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          if (_searchController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                _filterPurchases();
              },
              icon: const Icon(Icons.clear),
              label: const Text('Clear Search'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPurchaseCard(PurchaseModel purchase) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showPurchaseDetails(purchase),
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
                          purchase.invoiceNo,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(purchase.createdAt),
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
                      color: purchase.status == 'completed'
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: purchase.status == 'completed'
                            ? Colors.green.shade300
                            : Colors.orange.shade300,
                      ),
                    ),
                    child: Text(
                      purchase.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: purchase.status == 'completed'
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
                      '\$${purchase.totalAmount.toStringAsFixed(2)}',
                      Icons.attach_money,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInfoItem(
                      'Payment',
                      purchase.isCredit ? 'Credit' : 'Cash',
                      purchase.isCredit ? Icons.credit_card : Icons.money,
                      purchase.isCredit ? Colors.purple : Colors.blue,
                    ),
                  ),
                ],
              ),
              if (purchase.isReturn) ...[
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

  Widget _buildStatusBadge(PurchaseModel purchase) {
    Color color;
    String text;
    IconData icon;

    if (purchase.isReturn) {
      color = Colors.red;
      text = 'RETURN';
      icon = Icons.keyboard_return;
    } else if (purchase.status == 'completed') {
      color = Colors.green;
      text = 'COMPLETED';
      icon = Icons.check_circle;
    } else {
      color = Colors.orange;
      text = 'DRAFT';
      icon = Icons.drafts;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showPurchaseDetails(PurchaseModel purchase) {
    // Navigate to purchase details screen or show bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
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
                      purchase.invoiceNo,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Purchase Details',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(purchase),
              ],
            ),
            const SizedBox(height: 20),

            // Details
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Invoice Number', purchase.invoiceNo),
                    _buildDetailRow(
                      'Date',
                      _formatDateTime(purchase.createdAt),
                    ),
                    _buildDetailRow(
                      'Payment Method',
                      purchase.isCredit ? 'Credit' : 'Cash',
                    ),
                    _buildDetailRow('Status', purchase.status.toUpperCase()),
                    if (purchase.isReturn && purchase.originalId != null)
                      _buildDetailRow(
                        'Original Purchase',
                        purchase.originalId!,
                      ),
                    const SizedBox(height: 20),
                    _buildPurchaseItemsSection(purchase),
                    const SizedBox(height: 20),
                    _buildDetailRow(
                      'Subtotal',
                      '\$${(purchase.subtotals ?? 0.0).toStringAsFixed(2)}',
                    ),
                    _buildDetailRow(
                      'Discount',
                      '\$${(purchase.discount ?? 0.0).toStringAsFixed(2)}',
                    ),
                    _buildDetailRow(
                      'Tax',
                      '\$${(purchase.tax ?? 0.0).toStringAsFixed(2)}',
                    ),
                    const Divider(thickness: 2),
                    _buildDetailRow(
                      'Total Amount',
                      '\$${purchase.totalAmount.toStringAsFixed(2)}',
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),

            // Action buttons
            if (purchase.status == 'completed' && !purchase.isReturn) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _processReturn(purchase);
                  },
                  icon: const Icon(Icons.keyboard_return),
                  label: const Text('Process Return'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? Colors.purple.shade700 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseItemsSection(PurchaseModel purchase) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Items Purchased',
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
          child: FutureBuilder<List<ItemModel>>(
            future: Provider.of<PurchaseProvider>(context, listen: false)
                .getPurchaseItems(purchase.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Failed to load items',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red,
                      ),
                    ),
                  ),
                );
              }

              final items = snapshot.data!;
              if (items.isEmpty) {
                return const Center(
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
                );
              }

              return Column(
                children: items.map((item) => _buildPurchaseItemRow(item)).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseItemRow(ItemModel item) {
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
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _processReturn(PurchaseModel purchase) {
    Navigator.pushNamed(
      context,
      '/process-purchase-return',
      arguments: {'purchase': purchase},
    ).then((_) {
      // Refresh the list when returning from return processing
      _loadPurchaseHistory();
    });
  }
}
