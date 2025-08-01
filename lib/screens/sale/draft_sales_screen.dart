import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product_model.dart';
import '../../models/sale_model.dart';
import '../../models/sale_purchase_item_model.dart';
import '../../models/user_model.dart';
import '../../providers/sales_provider.dart';
import 'add_sale_screen.dart';

class DraftSalesScreen extends StatefulWidget {
  const DraftSalesScreen({super.key});

  @override
  State<DraftSalesScreen> createState() => _DraftSalesScreenState();
}

class _DraftSalesScreenState extends State<DraftSalesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDraftSales();
      _searchController.addListener(_filterSales);
    });
  }

  void _filterSales() {
    // This will be implemented when search functionality is needed
    // For now, it's just a placeholder
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadDraftSales() async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    await salesProvider.loadDraftSales();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Draft Sales'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDraftSales,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<SalesProvider>(
        builder: (context, salesProvider, child) {
          if (salesProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (salesProvider.error != null) {
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
                    'Error loading draft sales',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    salesProvider.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadDraftSales,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (salesProvider.draftSales.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.drafts_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Draft Sales',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a new sale and save as draft to see it here',
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

          return RefreshIndicator(
            onRefresh: () async => _loadDraftSales(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: salesProvider.draftSales.length,
              itemBuilder: (context, index) {
                final sale = salesProvider.draftSales[index];
                return _buildDraftSaleCard(sale, salesProvider);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDraftSaleCard(SaleModel sale, SalesProvider salesProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
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
                            color: Colors.orange,
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
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Text(
                      'DRAFT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editSale(sale),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _completeSale(sale, salesProvider),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Complete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () => _deleteDraft(sale, salesProvider),
                    icon: const Icon(Icons.delete),
                    color: Colors.red,
                    tooltip: 'Delete Draft',
                  ),
                ],
              ),
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showSaleDetails(SaleModel sale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraftSaleDetailsSheet(sale: sale),
    );
  }

  void _editSale(SaleModel sale) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddSaleScreen(),
        settings: RouteSettings(arguments: {'editSale': sale, 'isDraft': true}),
      ),
    ).then((_) {
      // Refresh the draft sales list when returning from edit
      _loadDraftSales();
    });
  }

  void _completeSale(SaleModel sale, SalesProvider salesProvider) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Sale'),
        content: Text(
          'Are you sure you want to complete sale ${sale.invoiceNo}?\n\nThis will:\n• Update stock levels\n• Process payment (if credit)\n• Make the sale non-editable',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await salesProvider.completeSale(sale.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sale ${sale.invoiceNo} completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadDraftSales(); // Refresh the list
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete sale: ${salesProvider.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteDraft(SaleModel sale, SalesProvider salesProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Draft'),
        content: Text(
          'Are you sure you want to delete draft sale ${sale.invoiceNo}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await salesProvider.deleteDraftSale(sale.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Draft sale ${sale.invoiceNo} deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete draft: ${salesProvider.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class DraftSaleDetailsSheet extends StatefulWidget {
  final SaleModel sale;

  const DraftSaleDetailsSheet({super.key, required this.sale});

  @override
  State<DraftSaleDetailsSheet> createState() => _DraftSaleDetailsSheetState();
}

class _DraftSaleDetailsSheetState extends State<DraftSaleDetailsSheet> {
  List<ItemModel> _saleItems = [];
  List<ProductModel> _products = [];
  List<UserModel> _customers = [];
  bool _isLoadingItems = true;
  String? _itemsError;
  String _customerName = "";

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSaleItems();
    });
  }

  void _loadSaleItems() async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);

    try {
      setState(() {
        _isLoadingItems = true;
        _itemsError = null;
      });

      // Load initial data (products and customers)
      await salesProvider.loadInitialData();
      _products = salesProvider.products;
      _customers = salesProvider.customers;

      // Find customer name
      final customer = _customers.firstWhere(
        (c) => c.id == widget.sale.customerId,
        orElse: () => UserModel(
          id: widget.sale.customerId,
          name: "Unknown Customer",
          phoneNumber: "",
          email: "",
          role: "customer",
          createdAt: DateTime.now(),
        ),
      );

      _customerName = customer.name;

      // Load sale items
      final items = await salesProvider.getSaleItems(widget.sale.id);
      setState(() {
        _saleItems = items;
        _isLoadingItems = false;
      });
    } catch (e) {
      setState(() {
        _itemsError = e.toString();
        _isLoadingItems = false;
      });
    }
  }

  ProductModel? _getProductById(String productId) {
    try {
      return _products.firstWhere((product) => product.id == productId);
    } catch (e) {
      return null;
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
                    'Draft Sale Details',
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
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Text(
                  'DRAFT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
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
                    _buildDetailRow('Customer', _customerName),
                  ]),
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
                  const SizedBox(height: 20),

                  // Sale Items section
                  const Text(
                    'Sale Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildSaleItemsSection(),
                ],
              ),
            ),
          ),

          // Action buttons
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddSaleScreen(),
                        settings: RouteSettings(
                          arguments: {'editSale': widget.sale, 'isDraft': true},
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Sale'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final salesProvider = Provider.of<SalesProvider>(
                      context,
                      listen: false,
                    );
                    final success = await salesProvider.completeSale(
                      widget.sale.id,
                    );
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Sale ${widget.sale.invoiceNo} completed successfully!',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to complete sale: ${salesProvider.error}',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Complete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaleItemsSection() {
    if (_isLoadingItems) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading sale items...'),
            ],
          ),
        ),
      );
    }

    if (_itemsError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600, size: 32),
            const SizedBox(height: 8),
            Text(
              'Error loading sale items',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _itemsError!,
              style: TextStyle(color: Colors.red.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadSaleItems,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_saleItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Text(
          'No items found for this sale',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Product',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Qty',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Price',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Items
          ...(_saleItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final product = _getProductById(item.productId);

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: index < _saleItems.length - 1
                      ? BorderSide(color: Colors.grey.shade200)
                      : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product?.name ?? 'Unknown Product',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (product?.unit != null)
                          Text(
                            'Unit: ${product!.unit}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${item.quantity}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '\$${item.unitPrice.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '\$${item.totalPrice.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList()),
          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border(top: BorderSide(color: Colors.green.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Items: ${_saleItems.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                Text(
                  'Total Qty: ${_saleItems.fold<double>(0, (sum, item) => sum + item.quantity)}',
                  style: TextStyle(
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

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
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
              color: isTotal ? Colors.green.shade700 : Colors.black,
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
