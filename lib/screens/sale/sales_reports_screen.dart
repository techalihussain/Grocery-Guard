import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/product_provider.dart';
import '../../providers/sales_provider.dart';

// Data class for product performance metrics
class ProductPerformance {
  final String productId;
  final String productName;
  final double totalQuantitySold;
  final double totalRevenue;
  final int numberOfSales;
  final double averagePrice;

  ProductPerformance({
    required this.productId,
    required this.productName,
    required this.totalQuantitySold,
    required this.totalRevenue,
    required this.numberOfSales,
    required this.averagePrice,
  });
}

// Data class for accumulating product sales data
class ProductSalesData {
  final String productId;
  final String productName;
  final String category;
  double totalQuantitySold;
  double totalRevenue;
  int numberOfSales;

  ProductSalesData({
    required this.productId,
    required this.productName,
    required this.category,
    required this.totalQuantitySold,
    required this.totalRevenue,
    this.numberOfSales = 1,
  });

  // Method to add a sale with double quantity and revenue
  void addSale(double quantity, double revenue) {
    totalQuantitySold += quantity;
    totalRevenue += revenue;
    numberOfSales += 1;
  }

  // Convert to ProductPerformance for display
  ProductPerformance toProductPerformance() {
    return ProductPerformance(
      productId: productId,
      productName: productName,
      totalQuantitySold: totalQuantitySold,
      totalRevenue: totalRevenue,
      numberOfSales: numberOfSales,
      averagePrice: numberOfSales > 0 ? totalRevenue / numberOfSales : 0.0,
    );
  }
}

class SalesReportsScreen extends StatefulWidget {
  const SalesReportsScreen({super.key});

  @override
  State<SalesReportsScreen> createState() => _SalesReportsScreenState();
}

class _SalesReportsScreenState extends State<SalesReportsScreen> {
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
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );

    await Future.wait([
      salesProvider.loadAllSales(), // Load all sales for comprehensive reports
      productProvider.initialize(), // Load products for names
    ]);
  }

  // Calculate top performing products from sales data
  Future<List<ProductPerformance>> _calculateTopPerformingProducts(
    List<dynamic> sales,
  ) async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );

    // Map to store product performance data
    final Map<String, Map<String, dynamic>> productStats = {};

    // Get all sale items for the filtered sales
    for (var sale in sales) {
      if (sale.isReturn) continue; // Skip returns for performance calculation

      try {
        final saleItems = await salesProvider.getSaleItems(sale.id);

        for (var item in saleItems) {
          if (!productStats.containsKey(item.productId)) {
            productStats[item.productId] = {
              'totalQuantity': 0.0,
              'totalRevenue': 0.0,
              'numberOfSales': 0,
              'totalPrice': 0.0,
            };
          }

          productStats[item.productId]!['totalQuantity'] += item.quantity;
          productStats[item.productId]!['totalRevenue'] += item.totalPrice;
          productStats[item.productId]!['numberOfSales'] += 1;
          productStats[item.productId]!['totalPrice'] += item.totalPrice;
        }
      } catch (e) {
        // Skip this sale if we can't get its items
        continue;
      }
    }

    // Convert to ProductPerformance objects
    final List<ProductPerformance> performances = [];

    for (var entry in productStats.entries) {
      final productId = entry.key;
      final stats = entry.value;

      // Get product name
      final product = productProvider.getProductFromList(productId);
      final productName = product?.name ?? 'Unknown Product';

      final performance = ProductPerformance(
        productId: productId,
        productName: productName,
        totalQuantitySold: stats['totalQuantity'],
        totalRevenue: stats['totalRevenue'],
        numberOfSales: stats['numberOfSales'],
        averagePrice: stats['numberOfSales'] > 0
            ? stats['totalRevenue'] / stats['numberOfSales']
            : 0.0,
      );

      performances.add(performance);
    }

    // Sort by total revenue (descending) and take top 5
    performances.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    return performances.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Reports'),
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
            _buildSalesBreakdown(),
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
    return Consumer<SalesProvider>(
      builder: (context, salesProvider, child) {
        final filteredSales = _getFilteredSales(salesProvider.allSales);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Sales',
                    '\$${_calculateTotalSales(filteredSales).toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Orders',
                    '${filteredSales.where((sale) => !sale.isReturn).length}',
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
                    'Cash Sales',
                    '\$${_calculateCashSales(filteredSales).toStringAsFixed(2)}',
                    Icons.money,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Credit Sales',
                    '\$${_calculateCreditSales(filteredSales).toStringAsFixed(2)}',
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
                    '\$${_calculateReturns(filteredSales).toStringAsFixed(2)}',
                    Icons.keyboard_return,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Net Sales',
                    '\$${(_calculateTotalSales(filteredSales) - _calculateReturns(filteredSales)).toStringAsFixed(2)}',
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

  Widget _buildSalesBreakdown() {
    return Consumer<SalesProvider>(
      builder: (context, salesProvider, child) {
        final filteredSales = _getFilteredSales(salesProvider.allSales);
        final totalSales = _calculateTotalSales(filteredSales);
        final cashSales = _calculateCashSales(filteredSales);
        final creditSales = _calculateCreditSales(filteredSales);
        final completedSales = filteredSales.where(
          (sale) => sale.status == 'completed' && !sale.isReturn,
        );
        final draftSales = filteredSales.where(
          (sale) => sale.status == 'drafted',
        );
        final returns = filteredSales.where((sale) => sale.isReturn);

        final cashPercentage = totalSales > 0
            ? (cashSales / totalSales * 100)
            : 0.0;
        final creditPercentage = totalSales > 0
            ? (creditSales / totalSales * 100)
            : 0.0;
        final completedPercentage = filteredSales.isNotEmpty
            ? (completedSales.length / filteredSales.length * 100)
            : 0.0;
        final draftPercentage = filteredSales.isNotEmpty
            ? (draftSales.length / filteredSales.length * 100)
            : 0.0;
        final returnPercentage = filteredSales.isNotEmpty
            ? (returns.length / filteredSales.length * 100)
            : 0.0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sales Breakdown',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildBreakdownItem('Cash Sales', cashPercentage, Colors.blue),
                const SizedBox(height: 8),
                _buildBreakdownItem(
                  'Credit Sales',
                  creditPercentage,
                  Colors.purple,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                _buildBreakdownItem(
                  'Completed Sales',
                  completedPercentage,
                  Colors.green,
                ),
                const SizedBox(height: 8),
                _buildBreakdownItem(
                  'Draft Sales',
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
    return Consumer<SalesProvider>(
      builder: (context, salesProvider, child) {
        final filteredSales = _getFilteredSales(salesProvider.allSales);

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
                      'Top Performing Products',
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
                FutureBuilder<List<ProductPerformance>>(
                  future: _calculateTopPerformingProducts(filteredSales),
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
                                'Complete some sales to see top performers',
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
                          child: Row(
                            children: [
                              const SizedBox(width: 8),
                              const Expanded(
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
                              const Expanded(
                                flex: 2,
                                child: Text(
                                  'Qty Sold',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                              ),
                              const Expanded(
                                flex: 2,
                                child: Text(
                                  'Revenue',
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

  Widget _buildProductPerformanceItem(ProductPerformance product, int rank) {
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
                  '${product.numberOfSales} sale${product.numberOfSales == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // Quantity sold
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  '${product.totalQuantitySold}',
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
          // Revenue
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${product.totalRevenue.toStringAsFixed(0)}',
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
    return Consumer<SalesProvider>(
      builder: (context, salesProvider, child) {
        final recentSales = salesProvider.allSales.take(5).toList();

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
                if (recentSales.isEmpty)
                  const Center(
                    child: Text(
                      'No recent activity',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ...recentSales.map((sale) {
                    String title;
                    IconData icon;
                    Color color;

                    if (sale.isReturn) {
                      title = 'Return Processed';
                      icon = Icons.keyboard_return;
                      color = Colors.red;
                    } else if (sale.status == 'completed') {
                      title = 'Sale Completed';
                      icon = Icons.check_circle;
                      color = Colors.green;
                    } else {
                      title = 'Draft Created';
                      icon = Icons.drafts;
                      color = Colors.orange;
                    }

                    return _buildActivityItem(
                      title,
                      '${sale.invoiceNo} • \$${sale.totalAmount.abs().toStringAsFixed(2)}',
                      _getTimeAgo(sale.createdAt),
                      icon,
                      color,
                    );
                  }),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/sales-history');
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

  void _showPeriodSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Report Period'),
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

  double _calculateTotalSales(List<dynamic> sales) {
    return sales
        .where((sale) => !sale.isReturn)
        .fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  double _calculateCashSales(List<dynamic> sales) {
    return sales
        .where((sale) => !sale.isCredit && !sale.isReturn)
        .fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  double _calculateCreditSales(List<dynamic> sales) {
    return sales
        .where((sale) => sale.isCredit && !sale.isReturn)
        .fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  double _calculateReturns(List<dynamic> sales) {
    return sales
        .where((sale) => sale.isReturn)
        .fold(0.0, (sum, sale) => sum + sale.totalAmount.abs());
  }

  List<dynamic> _getFilteredSales(List<dynamic> allSales) {
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'Today':
        return allSales.where((sale) {
          final saleDate = sale.createdAt;
          return saleDate.year == now.year &&
              saleDate.month == now.month &&
              saleDate.day == now.day;
        }).toList();

      case 'This Week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        return allSales.where((sale) {
          final saleDate = sale.createdAt;
          return saleDate.isAfter(
                weekStart.subtract(const Duration(days: 1)),
              ) &&
              saleDate.isBefore(weekEnd.add(const Duration(days: 1)));
        }).toList();

      case 'This Month':
        return allSales.where((sale) {
          final saleDate = sale.createdAt;
          return saleDate.year == now.year && saleDate.month == now.month;
        }).toList();

      case 'Custom':
        if (_customDateRange != null) {
          return allSales.where((sale) {
            final saleDate = sale.createdAt;
            return saleDate.isAfter(
                  _customDateRange!.start.subtract(const Duration(days: 1)),
                ) &&
                saleDate.isBefore(
                  _customDateRange!.end.add(const Duration(days: 1)),
                );
          }).toList();
        }
        return allSales;

      default:
        return allSales;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}
