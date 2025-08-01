import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/purchase_provider.dart';
import '../../models/purchase_model.dart';
import '../../models/sale_purchase_item_model.dart';

class VendorSalesHistoryScreen extends StatefulWidget {
  final String vendorId;

  const VendorSalesHistoryScreen({super.key, required this.vendorId});

  @override
  State<VendorSalesHistoryScreen> createState() => _VendorSalesHistoryScreenState();
}

class _VendorSalesHistoryScreenState extends State<VendorSalesHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
    await purchaseProvider.loadAllPurchases();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Sales History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
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
                  Icon(Icons.error, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading sales history',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    purchaseProvider.error!,
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

          // Filter purchases for this vendor
          final vendorPurchases = purchaseProvider.allPurchases
              .where((purchase) => purchase.vendorId == widget.vendorId)
              .toList();

          // Sort by date (newest first)
          vendorPurchases.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          // Calculate summary statistics
          final completedPurchases = vendorPurchases
              .where((p) => p.status == 'completed' && !p.isReturn)
              .toList();
          final totalSales = completedPurchases.length;
          final totalRevenue = completedPurchases.fold<double>(
            0, (sum, purchase) => sum + purchase.totalAmount);
          final avgOrderValue = totalSales > 0 ? totalRevenue / totalSales : 0.0;

          return Column(
            children: [
              // Summary Cards
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Sales',
                        totalSales.toString(),
                        Icons.shopping_cart,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Revenue',
                        '\$${totalRevenue.toStringAsFixed(2)}',
                        Icons.attach_money,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Avg Order',
                        '\$${avgOrderValue.toStringAsFixed(2)}',
                        Icons.trending_up,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              // Sales History List
              Expanded(
                child: vendorPurchases.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No sales history found',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Your sales will appear here once orders are placed',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: vendorPurchases.length,
                        itemBuilder: (context, index) {
                          final purchase = vendorPurchases[index];
                          return _buildPurchaseCard(purchase);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseCard(PurchaseModel purchase) {
    final statusColor = _getStatusColor(purchase.status, purchase.isReturn);
    final statusText = _getStatusText(purchase.status, purchase.isReturn);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(
            _getStatusIcon(purchase.status, purchase.isReturn),
            color: statusColor,
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
            Text(DateFormat('MMM dd, yyyy • HH:mm').format(purchase.createdAt)),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
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
        trailing: Text(
          '\$${purchase.totalAmount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: purchase.isReturn ? Colors.red : Colors.green,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (purchase.isReturn && purchase.originalId != null) ...[
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Return for Order #${purchase.originalId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem('Payment Method', purchase.paymentMethod.toUpperCase()),
                    ),
                    Expanded(
                      child: _buildDetailItem('Credit Sale', purchase.isCredit ? 'Yes' : 'No'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (purchase.tax != null || purchase.discount != null) ...[
                  Row(
                    children: [
                      if (purchase.tax != null)
                        Expanded(
                          child: _buildDetailItem('Tax', '\$${purchase.tax!.toStringAsFixed(2)}'),
                        ),
                      if (purchase.discount != null)
                        Expanded(
                          child: _buildDetailItem('Discount', '\$${purchase.discount!.toStringAsFixed(2)}'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                FutureBuilder<List<ItemModel>>(
                  future: Provider.of<PurchaseProvider>(context, listen: false)
                      .getPurchaseItems(purchase.id),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Items:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          ...snapshot.data!.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.quantity}x @ \$${item.unitPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Text(
                                  '\$${item.totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status, bool isReturn) {
    if (isReturn) return Colors.red;
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'drafted':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status, bool isReturn) {
    if (isReturn) return 'RETURN';
    switch (status) {
      case 'completed':
        return 'COMPLETED';
      case 'drafted':
        return 'DRAFT';
      default:
        return status.toUpperCase();
    }
  }

  IconData _getStatusIcon(String status, bool isReturn) {
    if (isReturn) return Icons.assignment_return;
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'drafted':
        return Icons.edit_note;
      default:
        return Icons.help_outline;
    }
  }
}