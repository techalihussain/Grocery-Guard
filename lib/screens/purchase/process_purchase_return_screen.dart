import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/purchase_model.dart';
import '../../models/sale_purchase_item_model.dart';
import '../../providers/purchase_provider.dart';

class ProcessPurchaseReturnScreen extends StatefulWidget {
  const ProcessPurchaseReturnScreen({super.key});

  @override
  State<ProcessPurchaseReturnScreen> createState() =>
      _ProcessPurchaseReturnScreenState();
}

class _ProcessPurchaseReturnScreenState
    extends State<ProcessPurchaseReturnScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PurchaseModel> _completedPurchases = [];
  List<PurchaseModel> _filteredPurchases = [];
  PurchaseModel? _selectedPurchase;
  List<ItemModel> _purchaseItems = [];
  bool _loadingItems = false;

  // Map to track return quantities for each product ID
  final Map<String, double> _returnQuantities = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() async {
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );
    await Future.wait([
      purchaseProvider.loadProducts(),
      _loadCompletedPurchases(),
    ]);
  }

  Future<void> _loadCompletedPurchases() async {
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );
    // Load all purchases to get completed ones for returns
    await purchaseProvider.loadAllPurchases();
    if (mounted) {
      setState(() {
        _completedPurchases = purchaseProvider.allPurchases
            .where(
              (purchase) =>
                  purchase.status == 'completed' && !purchase.isReturn,
            )
            .toList();
        _filteredPurchases = _completedPurchases;
      });
    }
  }

  void _filterPurchases(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPurchases = _completedPurchases;
      } else {
        _filteredPurchases = _completedPurchases
            .where(
              (purchase) =>
                  purchase.invoiceNo.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  purchase.vendorId.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Process Purchase Return'),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCompletedPurchases,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _selectedPurchase == null
          ? _buildPurchaseSelection()
          : _buildReturnProcess(),
    );
  }

  Widget _buildPurchaseSelection() {
    return Column(
      children: [
        // Search bar
        Container(
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
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by invoice number or vendor...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _filterPurchases('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            onChanged: _filterPurchases,
          ),
        ),

        // Purchases list
        Expanded(
          child: Consumer<PurchaseProvider>(
            builder: (context, purchaseProvider, child) {
              if (purchaseProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_filteredPurchases.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Completed Purchases Found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Complete some purchases to process returns',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredPurchases.length,
                itemBuilder: (context, index) {
                  final purchase = _filteredPurchases[index];
                  return _buildPurchaseCard(purchase);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseCard(PurchaseModel purchase) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _selectPurchase(purchase),
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
                            Text(
                              purchase.invoiceNo,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 8),
                            FutureBuilder<bool>(
                              future: Provider.of<PurchaseProvider>(
                                context,
                                listen: false,
                              ).hasReturns(purchase.id),
                              builder: (context, snapshot) {
                                if (snapshot.data == true) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.orange.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      'HAS RETURNS',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
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
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey.shade400,
                    size: 16,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReturnProcess() {
    return Column(
      children: [
        // Selected purchase header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            border: Border(bottom: BorderSide(color: Colors.red.shade200)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedPurchase = null;
                    _returnQuantities.clear();
                  });
                },
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Processing Return for ${_selectedPurchase!.invoiceNo}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Total: \$${_selectedPurchase!.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Return items section
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Items to Return',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Purchase items list
                Expanded(
                  child: _loadingItems
                      ? const Center(child: CircularProgressIndicator())
                      : _purchaseItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.assignment_return,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Items Available for Return',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'All items from this purchase have already been returned',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _purchaseItems.length,
                          itemBuilder: (context, index) {
                            final item = _purchaseItems[index];
                            final isSelected = _returnQuantities.containsKey(
                              item.productId,
                            );

                            return _buildPurchaseItemCard(item, isSelected);
                          },
                        ),
                ),

                // Return summary
                if (_returnQuantities.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Return Summary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Items to return: ${_returnQuantities.length}'),
                        Text(
                          'Return amount: \$${_calculateReturnAmount().toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Action buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.3),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _selectedPurchase = null;
                      _returnQuantities.clear();
                    });
                  },
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _returnQuantities.isNotEmpty
                      ? _processReturn
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Process Return'),
                ),
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildPurchaseItemCard(ItemModel item, bool isSelected) {
    final returnQty = _returnQuantities[item.productId] ?? 0;
    final maxQty = item.quantity;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? Colors.red : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product info row
            Row(
              children: [
                // Selection checkbox
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.red : Colors.grey,
                      width: 2,
                    ),
                    color: isSelected ? Colors.red : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
                const SizedBox(width: 12),

                // Product details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getProductName(item.productId),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Text(
                              'Available: $maxQty',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Unit Price: \$${item.unitPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Toggle selection button
                IconButton(
                  onPressed: () => _toggleReturnItem(item),
                  icon: Icon(
                    isSelected ? Icons.remove_circle : Icons.add_circle,
                    color: isSelected ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),

            // Quantity controls (only show when selected)
            if (isSelected) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Return Quantity:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Return Amount: \$${(returnQty * item.unitPrice).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Decrease button
                        IconButton(
                          onPressed: returnQty > 1
                              ? () => _updateReturnQuantity(
                                  item.productId,
                                  returnQty - 1,
                                )
                              : null,
                          icon: const Icon(Icons.remove),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.shade100,
                            foregroundColor: Colors.red.shade700,
                          ),
                        ),

                        // Quantity display
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Text(
                              '$returnQty',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        // Increase button
                        IconButton(
                          onPressed: returnQty < maxQty
                              ? () => _updateReturnQuantity(
                                  item.productId,
                                  returnQty + 1,
                                )
                              : null,
                          icon: const Icon(Icons.add),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.shade100,
                            foregroundColor: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),

                    // Quick quantity buttons
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (maxQty >= 1)
                          _buildQuickQuantityButton(item.productId, 1, maxQty),
                        if (maxQty >= 5)
                          _buildQuickQuantityButton(item.productId, 5, maxQty),
                        if (maxQty >= 10)
                          _buildQuickQuantityButton(item.productId, 10, maxQty),
                        const Spacer(),
                        _buildQuickQuantityButton(
                          item.productId,
                          maxQty,
                          maxQty,
                          label: 'All',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _toggleReturnItem(ItemModel item) {
    setState(() {
      if (_returnQuantities.containsKey(item.productId)) {
        // Remove from return items
        _returnQuantities.remove(item.productId);
      } else {
        // Add to return items with quantity 1
        _returnQuantities[item.productId] = 1;
      }
    });
  }

  void _updateReturnQuantity(String productId, double quantity) {
    setState(() {
      if (quantity <= 0) {
        _returnQuantities.remove(productId);
      } else {
        _returnQuantities[productId] = quantity;
      }
    });
  }

  Widget _buildQuickQuantityButton(
    String productId,
    double quantity,
    double maxQty, {
    String? label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton(
        onPressed: quantity <= maxQty
            ? () => _updateReturnQuantity(productId, quantity)
            : null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minimumSize: const Size(0, 32),
          side: BorderSide(color: Colors.red.shade300),
          foregroundColor: Colors.red.shade700,
        ),
        child: Text(label ?? '$quantity', style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  String _getProductName(String productId) {
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );
    try {
      final product = purchaseProvider.products.firstWhere(
        (p) => p.id == productId,
      );
      return product.name;
    } catch (e) {
      return 'Product ID: $productId'; // Fallback if product not found
    }
  }

  void _selectPurchase(PurchaseModel purchase) {
    setState(() {
      _selectedPurchase = purchase;
      _returnQuantities.clear();
      _purchaseItems.clear();
      _loadingItems = true;
    });
    _loadPurchaseItems(purchase.id);
  }

  void _loadPurchaseItems(String purchaseId) async {
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );
    final items = await purchaseProvider.getAvailableItemsForReturn(purchaseId);

    if (mounted) {
      setState(() {
        _purchaseItems = items;
        _loadingItems = false;
      });
    }
  }

  double _calculateReturnAmount() {
    double total = 0.0;
    for (var item in _purchaseItems) {
      final returnQty = _returnQuantities[item.productId] ?? 0;
      if (returnQty > 0) {
        total += returnQty * item.unitPrice;
      }
    }
    return total;
  }

  // Helper method to show loading dialog
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  // Helper method to hide loading dialog
  void _hideLoadingDialog() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _processReturn() async {
    if (_selectedPurchase == null || _returnQuantities.isEmpty) {
      return;
    }

    // For cash purchases, only cash refund is available
    // For credit purchases, both options are available
    final isCashPurchase = !_selectedPurchase!.isCredit;

    String? refundMethod;

    if (isCashPurchase) {
      // For cash purchases, automatically use cash refund
      refundMethod = 'cash_refund';
    } else {
      // For credit purchases, show selection dialog
      refundMethod = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Refund Method'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Credit Adjustment'),
                subtitle: const Text('Reduce vendor balance'),
                leading: const Icon(Icons.account_balance),
                onTap: () => Navigator.pop(context, 'credit_adjustment'),
              ),
              ListTile(
                title: const Text('Cash Refund'),
                subtitle: const Text('Get cash back from vendor'),
                leading: const Icon(Icons.money),
                onTap: () => Navigator.pop(context, 'cash_refund'),
              ),
            ],
          ),
        ),
      );
    }

    if (refundMethod == null) return;

    // Create return items list
    final returnItems = <ItemModel>[];
    for (var item in _purchaseItems) {
      final returnQty = _returnQuantities[item.productId];
      if (returnQty != null && returnQty > 0) {
        returnItems.add(
          item.copyWith(
            quantity: returnQty,
            totalPrice: returnQty * item.unitPrice,
          ),
        );
      }
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Return'),
        content: Text(
          'Process return for ${returnItems.length} items?\n\n'
          'Return amount: \$${_calculateReturnAmount().toStringAsFixed(2)}\n'
          'Refund method: ${refundMethod == 'credit_adjustment' ? 'Credit Adjustment' : 'Cash Refund'}',
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
            child: const Text('Process Return'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    _showLoadingDialog('Processing return...');

    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );

    try {
      final success = await purchaseProvider.processReturn(
        _selectedPurchase!.id,
        returnItems,
        refundMethod: refundMethod,
      );

      _hideLoadingDialog();

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return processed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to process return: ${purchaseProvider.error}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      _hideLoadingDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing return: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
