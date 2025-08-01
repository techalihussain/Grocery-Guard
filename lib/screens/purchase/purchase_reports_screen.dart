import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/product_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../utils/unit_converter.dart';

// Data class for product performance metrics
class ProductPurchaseData {
  final String productId;
  final String productName;
  final String category;
  double totalQuantityPurchased;
  double totalCost;
  int numberOfPurchases;

  ProductPurchaseData({
    required this.productId,
    required this.productName,
    required this.category,
    required this.totalQuantityPurchased,
    required this.totalCost,
    required this.numberOfPurchases,
  });

  void addPurchase(double quantity, String itemUnit, String productBaseUnit, double cost) {
    // Convert quantity to base unit before adding
    final quantityInBaseUnit = UnitConverter.convertUnit(quantity, itemUnit, productBaseUnit);
    totalQuantityPurchased += quantityInBaseUnit;
    totalCost += cost;
    numberOfPurchases++;
  }

  double get averagePrice =>
      totalQuantityPurchased > 0 ? totalCost / totalQuantityPurchased : 0;
}

class PurchaseReportsScreen extends StatefulWidget {
  const PurchaseReportsScreen({super.key});

  @override
  State<PurchaseReportsScreen> createState() => _PurchaseReportsScreenState();
}

class _PurchaseReportsScreenState extends State<PurchaseReportsScreen> {
  String _selectedPeriod = 'Today';
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReports();
    });
  }

  void _loadReports() async {
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );

    await Future.wait([
      purchaseProvider
          .loadAllPurchases(), // Load all purchases for comprehensive reports
      productProvider.initialize(), // Load products for names
    ]);
  }

  // Calculate top performing products from purchase data
  Future<List<ProductPurchaseData>> _calculateTopPerformingProducts(
    List<dynamic> purchases,
  ) async {
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );

    // Map to store product performance data
    final Map<String, ProductPurchaseData> productMap = {};

    // Get all purchase items for the filtered purchases
    for (var purchase in purchases) {
      if (purchase.isReturn) {
        continue; // Skip returns for performance calculation
      }
      try {
        final purchaseItems = await purchaseProvider.getPurchaseItems(
          purchase.id,
        );

        for (var item in purchaseItems) {
          if (productMap.containsKey(item.productId)) {
            // Get product details for unit conversion
            final product = productProvider.products
                .where((p) => p.id == item.productId)
                .firstOrNull;
            final productBaseUnit = product?.unit ?? item.unit;
            productMap[item.productId]!.addPurchase(item.quantity, item.unit, productBaseUnit, item.totalPrice);
          } else {
            // Get product details
            final product = productProvider.products
                .where((p) => p.id == item.productId)
                .firstOrNull;

            // Convert initial quantity to base unit
            final productBaseUnit = product?.unit ?? item.unit;
            final quantityInBaseUnit = UnitConverter.convertUnit(item.quantity, item.unit, productBaseUnit);

            productMap[item.productId] = ProductPurchaseData(
              productId: item.productId,
              productName: product?.name ?? 'Unknown Product',
              category: product?.categoryId ?? 'Unknown',
              totalQuantityPurchased: quantityInBaseUnit,
              totalCost: item.totalPrice,
              numberOfPurchases: 1,
            );
          }
        }
      } catch (e) {
        // Skip this purchase if we can't get its items
        continue;
      }
    }

    // Convert to list and sort by total cost (descending)
    final sortedProducts = productMap.values.toList()
      ..sort((a, b) => b.totalCost.compareTo(a.totalCost));

    // Return top 5
    return sortedProducts.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Reports'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showPeriodSelector,
            tooltip: 'Filter Period',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 20),
            _buildSummaryCards(),
            const SizedBox(height: 20),
            _buildPurchaseBreakdown(),
            const SizedBox(height: 20),
            _buildTopPerformers(),
            const SizedBox(height: 20),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report Period',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: ['Today', 'This Week', 'This Month', 'Custom'].map((
                period,
              ) {
                return FilterChip(
                  label: Text(period),
                  selected: _selectedPeriod == period,
                  onSelected: (selected) {
                    if (selected) {
                      if (period == 'Custom') {
                        _selectCustomDateRange();
                      } else {
                        setState(() {
                          _selectedPeriod = period;
                          _customDateRange = null;
                        });
                        _loadReports();
                      }
                    }
                  },
                  selectedColor: Colors.teal.shade100,
                  checkmarkColor: Colors.teal.shade700,
                );
              }).toList(),
            ),
            if (_customDateRange != null) ...[
              const SizedBox(height: 8),
              Text(
                'Custom: ${_formatDate(_customDateRange!.start)} - ${_formatDate(_customDateRange!.end)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.teal.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Consumer<PurchaseProvider>(
      builder: (context, purchaseProvider, child) {
        final filteredPurchases = _getFilteredPurchases(
          purchaseProvider.allPurchases,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Purchase Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Purchases',
                    '\$${_calculateTotalPurchases(filteredPurchases).toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Orders',
                    '${filteredPurchases.where((purchase) => !purchase.isReturn).length}',
                    Icons.receipt_long,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Cash Purchases',
                    '\$${_calculateCashPurchases(filteredPurchases).toStringAsFixed(2)}',
                    Icons.money,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Credit Purchases',
                    '\$${_calculateCreditPurchases(filteredPurchases).toStringAsFixed(2)}',
                    Icons.credit_card,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Returns',
                    '\$${_calculateReturns(filteredPurchases).toStringAsFixed(2)}',
                    Icons.keyboard_return,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Net Purchases',
                    '\$${(_calculateTotalPurchases(filteredPurchases) - _calculateReturns(filteredPurchases)).toStringAsFixed(2)}',
                    Icons.trending_up,
                    Colors.teal,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(Icons.trending_up, color: color, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseBreakdown() {
    return Consumer<PurchaseProvider>(
      builder: (context, purchaseProvider, child) {
        final filteredPurchases = _getFilteredPurchases(
          purchaseProvider.allPurchases,
        );
        final totalPurchases = _calculateTotalPurchases(filteredPurchases);
        final cashPurchases = _calculateCashPurchases(filteredPurchases);
        final creditPurchases = _calculateCreditPurchases(filteredPurchases);
        final completedPurchases = filteredPurchases.where(
          (purchase) => purchase.status == 'completed' && !purchase.isReturn,
        );
        final draftPurchases = filteredPurchases.where(
          (purchase) => purchase.status == 'drafted',
        );
        final returns = filteredPurchases.where(
          (purchase) => purchase.isReturn,
        );

        final cashPercentage = totalPurchases > 0
            ? (cashPurchases / totalPurchases * 100)
            : 0.0;
        final creditPercentage = totalPurchases > 0
            ? (creditPurchases / totalPurchases * 100)
            : 0.0;
        final completedPercentage = filteredPurchases.isNotEmpty
            ? (completedPurchases.length / filteredPurchases.length * 100)
            : 0.0;
        final draftPercentage = filteredPurchases.isNotEmpty
            ? (draftPurchases.length / filteredPurchases.length * 100)
            : 0.0;
        final returnPercentage = filteredPurchases.isNotEmpty
            ? (returns.length / filteredPurchases.length * 100)
            : 0.0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Purchase Breakdown',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildBreakdownItem(
                  'Cash Purchases',
                  cashPercentage,
                  Colors.blue,
                ),
                const SizedBox(height: 8),
                _buildBreakdownItem(
                  'Credit Purchases',
                  creditPercentage,
                  Colors.purple,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                _buildBreakdownItem(
                  'Completed Purchases',
                  completedPercentage,
                  Colors.green,
                ),
                const SizedBox(height: 8),
                _buildBreakdownItem(
                  'Draft Purchases',
                  draftPercentage,
                  Colors.orange,
                ),
                const SizedBox(height: 8),
                _buildBreakdownItem('Returns', returnPercentage, Colors.red),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBreakdownItem(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Text(
              '${percentage.toInt()}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  Widget _buildTopPerformers() {
    return Consumer<PurchaseProvider>(
      builder: (context, purchaseProvider, child) {
        final filteredPurchases = _getFilteredPurchases(
          purchaseProvider.allPurchases,
        );

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Top Purchased Products',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.trending_up,
                      color: Colors.teal.shade600,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<ProductPurchaseData>>(
                  future: _calculateTopPerformingProducts(filteredPurchases),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 32,
                                color: Colors.red.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Error loading product data',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final topProducts = snapshot.data ?? [];

                    if (topProducts.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_outlined,
                                size: 32,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No product data available',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Complete some purchases to see top performers',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        // Header row
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Product',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Qty Purchased',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Total Cost',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Product list
                        ...topProducts.asMap().entries.map((entry) {
                          final index = entry.key;
                          final product = entry.value;
                          return _buildProductPerformanceItem(
                            product,
                            index + 1,
                          );
                        }),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductPerformanceItem(ProductPurchaseData product, int rank) {
    // Get rank color
    Color rankColor;
    switch (rank) {
      case 1:
        rankColor = Colors.amber;
        break;
      case 2:
        rankColor = Colors.grey.shade400;
        break;
      case 3:
        rankColor = Colors.orange.shade300;
        break;
      default:
        rankColor = Colors.blue.shade300;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: rankColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Product info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${product.numberOfPurchases} purchase${product.numberOfPurchases == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // Quantity purchased
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  '${product.totalQuantityPurchased}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Text(
                  'units',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // Total cost
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${product.totalCost.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text(
                  'avg \$${product.averagePrice.toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Consumer<PurchaseProvider>(
      builder: (context, purchaseProvider, child) {
        final recentPurchases = purchaseProvider.allPurchases.take(5).toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (recentPurchases.isEmpty)
                  const Center(
                    child: Text(
                      'No recent activity',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ...recentPurchases.map((purchase) {
                    String title;
                    IconData icon;
                    Color color;

                    if (purchase.isReturn) {
                      title = 'Return Processed';
                      icon = Icons.keyboard_return;
                      color = Colors.red;
                    } else if (purchase.status == 'completed') {
                      title = 'Purchase Completed';
                      icon = Icons.check_circle;
                      color = Colors.green;
                    } else {
                      title = 'Draft Created';
                      icon = Icons.drafts;
                      color = Colors.orange;
                    }

                    return _buildActivityItem(
                      title,
                      '${purchase.invoiceNo} • \$${purchase.totalAmount.abs().toStringAsFixed(2)}',
                      _getTimeAgo(purchase.createdAt),
                      icon,
                      color,
                    );
                  }),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/purchase-history');
                    },
                    child: const Text('View All Activity'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityItem(
    String title,
    String subtitle,
    String time,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // Helper methods for calculations
  List<dynamic> _getFilteredPurchases(List<dynamic> allPurchases) {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'This Week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'This Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'Custom':
        if (_customDateRange != null) {
          return allPurchases.where((purchase) {
            return purchase.createdAt.isAfter(
                  _customDateRange!.start.subtract(const Duration(days: 1)),
                ) &&
                purchase.createdAt.isBefore(
                  _customDateRange!.end.add(const Duration(days: 1)),
                );
          }).toList();
        }
        return allPurchases;
      default:
        return allPurchases;
    }

    return allPurchases.where((purchase) {
      return purchase.createdAt.isAfter(
        startDate.subtract(const Duration(days: 1)),
      );
    }).toList();
  }

  double _calculateTotalPurchases(List<dynamic> purchases) {
    return purchases
        .where((purchase) => !purchase.isReturn)
        .fold(0.0, (sum, purchase) => sum + purchase.totalAmount);
  }

  double _calculateCashPurchases(List<dynamic> purchases) {
    return purchases
        .where((purchase) => !purchase.isCredit && !purchase.isReturn)
        .fold(0.0, (sum, purchase) => sum + purchase.totalAmount);
  }

  double _calculateCreditPurchases(List<dynamic> purchases) {
    return purchases
        .where((purchase) => purchase.isCredit && !purchase.isReturn)
        .fold(0.0, (sum, purchase) => sum + purchase.totalAmount);
  }

  double _calculateReturns(List<dynamic> purchases) {
    return purchases
        .where((purchase) => purchase.isReturn)
        .fold(0.0, (sum, purchase) => sum + purchase.totalAmount.abs());
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customDateRange,
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = 'Custom';
        _customDateRange = picked;
      });
      _loadReports();
    }
  }

  void _showPeriodSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Period'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Today', 'This Week', 'This Month', 'Custom'].map((
            period,
          ) {
            return RadioListTile<String>(
              title: Text(period),
              value: period,
              groupValue: _selectedPeriod,
              onChanged: (value) {
                Navigator.pop(context);
                if (value == 'Custom') {
                  _selectCustomDateRange();
                } else {
                  setState(() {
                    _selectedPeriod = value!;
                    _customDateRange = null;
                  });
                  _loadReports();
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
