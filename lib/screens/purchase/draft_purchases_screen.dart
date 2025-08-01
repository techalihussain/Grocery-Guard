import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product_model.dart';
import '../../models/purchase_model.dart';
import '../../models/sale_purchase_item_model.dart';
import '../../models/user_model.dart';
import '../../providers/purchase_provider.dart';
import 'add_purchase_screen.dart';

class DraftPurchasesScreen extends StatefulWidget {
  const DraftPurchasesScreen({super.key});

  @override
  State<DraftPurchasesScreen> createState() => _DraftPurchasesScreenState();
}

class _DraftPurchasesScreenState extends State<DraftPurchasesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDraftPurchases();
      _searchController.addListener(_filterPurchases);
    });
  }

  void _filterPurchases() {
    // This will be implemented when search functionality is needed
    // For now, it's just a placeholder
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadDraftPurchases() async {
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );
    await purchaseProvider.loadDraftPurchases();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Draft Purchases'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDraftPurchases,
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
                    'Error loading draft purchases',
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
                    onPressed: _loadDraftPurchases,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (purchaseProvider.draftPurchases.isEmpty) {
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
                    'No Draft Purchases',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a new purchase and save as draft to see it here',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/add-purchase');
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Purchase'),
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
            onRefresh: () async => _loadDraftPurchases(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: purchaseProvider.draftPurchases.length,
              itemBuilder: (context, index) {
                final purchase = purchaseProvider.draftPurchases[index];
                return _buildDraftPurchaseCard(purchase, purchaseProvider);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDraftPurchaseCard(
    PurchaseModel purchase,
    PurchaseProvider purchaseProvider,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
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
                            color: Colors.orange,
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
                      '\${purchase.totalAmount.toStringAsFixed(2)}',
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editPurchase(purchase),
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
                      onPressed: () =>
                          _completePurchase(purchase, purchaseProvider),
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
                    onPressed: () => _deleteDraft(purchase, purchaseProvider),
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

  void _showPurchaseDetails(PurchaseModel purchase) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraftPurchaseDetailsSheet(purchase: purchase),
    );
  }

  void _editPurchase(PurchaseModel purchase) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddPurchaseScreen(),
        settings: RouteSettings(
          arguments: {'editPurchase': purchase, 'isDraft': true},
        ),
      ),
    ).then((_) {
      // Refresh the draft purchases list when returning from edit
      _loadDraftPurchases();
    });
  }

  void _completePurchase(
    PurchaseModel purchase,
    PurchaseProvider purchaseProvider,
  ) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Purchase'),
        content: Text(
          'Are you sure you want to complete purchase ${purchase.invoiceNo}?\n\nThis will:\n• Update stock levels\n• Process payment (if credit)\n• Make the purchase non-editable',
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
      final success = await purchaseProvider.completePurchase(purchase.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Purchase ${purchase.invoiceNo} completed successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadDraftPurchases(); // Refresh the list
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to complete purchase: ${purchaseProvider.error}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteDraft(
    PurchaseModel purchase,
    PurchaseProvider purchaseProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Draft'),
        content: Text(
          'Are you sure you want to delete draft purchase ${purchase.invoiceNo}?\n\nThis action cannot be undone.',
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
      final success = await purchaseProvider.deleteDraftPurchase(purchase.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Draft purchase ${purchase.invoiceNo} deleted successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete draft: ${purchaseProvider.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class DraftPurchaseDetailsSheet extends StatefulWidget {
  final PurchaseModel purchase;

  const DraftPurchaseDetailsSheet({super.key, required this.purchase});

  @override
  State<DraftPurchaseDetailsSheet> createState() =>
      _DraftPurchaseDetailsSheetState();
}

class _DraftPurchaseDetailsSheetState extends State<DraftPurchaseDetailsSheet> {
  List<ItemModel> _purchaseItems = [];
  List<ProductModel> _products = [];
  List<UserModel> _vendors = [];
  bool _isLoadingItems = true;
  String? _itemsError;
  String _vendorName = "";

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPurchaseItems();
    });
  }

  void _loadPurchaseItems() async {
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );

    try {
      setState(() {
        _isLoadingItems = true;
        _itemsError = null;
      });

      // Load initial data (products and vendors)
      await purchaseProvider.loadInitialData();
      _products = purchaseProvider.products;
      _vendors = purchaseProvider.vendors;

      // Find vendor name
      final vendor = _vendors.firstWhere(
        (v) => v.id == widget.purchase.vendorId,
        orElse: () => UserModel(
          id: widget.purchase.vendorId,
          name: "Unknown Vendor",
          phoneNumber: "",
          email: "",
          role: "vendor",
          createdAt: DateTime.now(),
        ),
      );

      _vendorName = vendor.name;

      // Load purchase items
      final items = await purchaseProvider.getPurchaseItems(widget.purchase.id);
      setState(() {
        _purchaseItems = items;
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
                    widget.purchase.invoiceNo,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Draft Purchase Details',
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

          // Purchase Information
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection('Purchase Information', [
                    _buildDetailRow(
                      'Invoice Number',
                      widget.purchase.invoiceNo,
                    ),
                    _buildDetailRow(
                      'Created Date',
                      _formatDateTime(widget.purchase.createdAt),
                    ),
                    _buildDetailRow(
                      'Payment Method',
                      widget.purchase.isCredit ? 'Credit' : 'Cash',
                    ),
                    _buildDetailRow('Vendor', _vendorName),
                  ]),
                  const SizedBox(height: 20),

                  _buildDetailSection('Amount Breakdown', [
                    _buildDetailRow(
                      'Subtotal',
                      '\${(widget.purchase.subtotals ?? 0.0).toStringAsFixed(2)}',
                    ),
                    _buildDetailRow(
                      'Discount',
                      '-\${(widget.purchase.discount ?? 0.0).toStringAsFixed(2)}',
                    ),
                    _buildDetailRow(
                      'Tax',
                      '\${(widget.purchase.tax ?? 0.0).toStringAsFixed(2)}',
                    ),
                    _buildDetailRow(
                      'Total Amount',
                      '\${widget.purchase.totalAmount.toStringAsFixed(2)}',
                      isTotal: true,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Purchase Items section
                  const Text(
                    'Purchase Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildPurchaseItemsSection(),
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
                        builder: (context) => const AddPurchaseScreen(),
                        settings: RouteSettings(
                          arguments: {
                            'editPurchase': widget.purchase,
                            'isDraft': true,
                          },
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Purchase'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final purchaseProvider = Provider.of<PurchaseProvider>(
                      context,
                      listen: false,
                    );
                    final success = await purchaseProvider.completePurchase(
                      widget.purchase.id,
                    );
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Purchase ${widget.purchase.invoiceNo} completed successfully!',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to complete purchase: ${purchaseProvider.error}',
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

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildPurchaseItemsSection() {
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
              Text('Loading purchase items...'),
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
              'Error loading purchase items',
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
              onPressed: _loadPurchaseItems,
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

    if (_purchaseItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Text(
          'No items found for this purchase',
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
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Product',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Qty',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Price',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
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
          ...(_purchaseItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final product = _getProductById(item.productId);

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: index < _purchaseItems.length - 1
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
                      '\${item.unitPrice.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '\${item.totalPrice.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
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
              color: Colors.purple.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Items: ${_purchaseItems.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
                Text(
                  'Total: \${widget.purchase.totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
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
}
