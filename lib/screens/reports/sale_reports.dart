import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:untitled/models/sale_model.dart';
import 'package:untitled/providers/sales_provider.dart';
import 'package:untitled/utils/responsive_utils.dart';
import 'package:untitled/utils/unit_converter.dart';

class SaleReports extends StatefulWidget {
  const SaleReports({super.key});

  @override
  State<SaleReports> createState() => _SaleReportsState();
}

class _SaleReportsState extends State<SaleReports> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    await salesProvider.loadAllSales();
    await salesProvider.loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Sales Reports",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(context.responsivePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Performance Analytics',
              style: ResponsiveUtils.getResponsiveTextStyle(
                context,
                baseSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Comprehensive sales data and insights',
              style: ResponsiveUtils.getResponsiveTextStyle(
                context,
                baseSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Consumer<SalesProvider>(
                builder: (context, salesProvider, child) {
                  if (salesProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (salesProvider.error != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, size: 64, color: Colors.red[300]),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading sales data',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            salesProvider.error!,
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

                  return GridView.count(
                    crossAxisCount: context.isTablet ? 2 : 1,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: context.isTablet ? 1.5 : 2.5,
                    children: [
                      _buildReportCard(
                        title: 'Daily Sales',
                        subtitle: 'View daily sales transactions and revenue',
                        icon: Icons.today,
                        color: Colors.blue,
                        onTap: () =>
                            _showDailySalesReport(salesProvider.allSales),
                      ),
                      _buildReportCard(
                        title: 'Monthly Sales',
                        subtitle: 'Monthly sales summary and trends',
                        icon: Icons.calendar_month,
                        color: Colors.green,
                        onTap: () =>
                            _showMonthlySalesReport(salesProvider.allSales),
                      ),
                      _buildReportCard(
                        title: 'Top Products',
                        subtitle: 'Best selling products and categories',
                        icon: Icons.star,
                        color: Colors.orange,
                        onTap: () => _showTopProductsReport(salesProvider),
                      ),
                      _buildReportCard(
                        title: 'Customer Analysis',
                        subtitle: 'Customer purchase patterns and insights',
                        icon: Icons.people,
                        color: Colors.purple,
                        onTap: () => _showCustomerAnalysisReport(salesProvider),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _showDailySalesReport(List<SaleModel> allSales) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailySalesReportScreen(sales: allSales),
      ),
    );
  }

  void _showMonthlySalesReport(List<SaleModel> allSales) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MonthlySalesReportScreen(sales: allSales),
      ),
    );
  }

  void _showTopProductsReport(SalesProvider salesProvider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TopProductsReportScreen(salesProvider: salesProvider),
      ),
    );
  }

  void _showCustomerAnalysisReport(SalesProvider salesProvider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CustomerAnalysisReportScreen(salesProvider: salesProvider),
      ),
    );
  }
}

// Daily Sales Report Screen
class DailySalesReportScreen extends StatelessWidget {
  final List<SaleModel> sales;

  const DailySalesReportScreen({super.key, required this.sales});

  @override
  Widget build(BuildContext context) {
    final completedSales = sales
        .where((sale) => sale.status == 'completed' && !sale.isReturn)
        .toList();

    // Group sales by date
    final Map<String, List<SaleModel>> salesByDate = {};
    for (var sale in completedSales) {
      final dateKey = DateFormat('yyyy-MM-dd').format(sale.createdAt);
      salesByDate[dateKey] = (salesByDate[dateKey] ?? [])..add(sale);
    }

    // Sort dates in descending order
    final sortedDates = salesByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Daily Sales Report'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: sortedDates.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No sales data available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedDates.length,
              itemBuilder: (context, index) {
                final date = sortedDates[index];
                final daySales = salesByDate[date]!;
                final totalRevenue = daySales.fold<double>(
                  0,
                  (sum, sale) => sum + sale.totalAmount,
                );
                final totalTransactions = daySales.length;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Text(
                      DateFormat(
                        'EEEE, MMM dd, yyyy',
                      ).format(DateTime.parse(date)),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '$totalTransactions transactions • \$${totalRevenue.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    children: daySales
                        .map(
                          (sale) => ListTile(
                            leading: CircleAvatar(
                              backgroundColor: sale.isCredit
                                  ? Colors.orange[100]
                                  : Colors.green[100],
                              child: Icon(
                                sale.isCredit
                                    ? Icons.credit_card
                                    : Icons.payments,
                                color: sale.isCredit
                                    ? Colors.orange
                                    : Colors.green,
                                size: 20,
                              ),
                            ),
                            title: Text('Invoice: ${sale.invoiceNo}'),
                            subtitle: Text(
                              '${sale.paymentMethod.toUpperCase()} • ${DateFormat('HH:mm').format(sale.createdAt)}',
                            ),
                            trailing: Text(
                              '\$${sale.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                );
              },
            ),
    );
  }
}

// Monthly Sales Report Screen
class MonthlySalesReportScreen extends StatelessWidget {
  final List<SaleModel> sales;

  const MonthlySalesReportScreen({super.key, required this.sales});

  @override
  Widget build(BuildContext context) {
    final completedSales = sales
        .where((sale) => sale.status == 'completed' && !sale.isReturn)
        .toList();

    // Group sales by month
    final Map<String, List<SaleModel>> salesByMonth = {};
    for (var sale in completedSales) {
      final monthKey = DateFormat('yyyy-MM').format(sale.createdAt);
      salesByMonth[monthKey] = (salesByMonth[monthKey] ?? [])..add(sale);
    }

    // Sort months in descending order
    final sortedMonths = salesByMonth.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Monthly Sales Report'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
      ),
      body: sortedMonths.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No sales data available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedMonths.length,
              itemBuilder: (context, index) {
                final month = sortedMonths[index];
                final monthSales = salesByMonth[month]!;
                final totalRevenue = monthSales.fold<double>(
                  0,
                  (sum, sale) => sum + sale.totalAmount,
                );
                final totalTransactions = monthSales.length;
                final avgTransactionValue = totalRevenue / totalTransactions;

                // Calculate cash vs credit breakdown
                final cashSales = monthSales.where((s) => !s.isCredit).length;
                final creditSales = monthSales.where((s) => s.isCredit).length;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat(
                            'MMMM yyyy',
                          ).format(DateTime.parse('$month-01')),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                'Total Revenue',
                                '\$${totalRevenue.toStringAsFixed(2)}',
                                Icons.attach_money,
                                Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricCard(
                                'Transactions',
                                totalTransactions.toString(),
                                Icons.receipt,
                                Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                'Avg Transaction',
                                '\$${avgTransactionValue.toStringAsFixed(2)}',
                                Icons.trending_up,
                                Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricCard(
                                'Cash/Credit',
                                '$cashSales/$creditSales',
                                Icons.payment,
                                Colors.purple,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Top Products Report Screen
class TopProductsReportScreen extends StatefulWidget {
  final SalesProvider salesProvider;

  const TopProductsReportScreen({super.key, required this.salesProvider});

  @override
  State<TopProductsReportScreen> createState() =>
      _TopProductsReportScreenState();
}

class _TopProductsReportScreenState extends State<TopProductsReportScreen> {
  Map<String, ProductSalesData> productSalesMap = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateTopProducts();
  }

  Future<void> _calculateTopProducts() async {
    final completedSales = widget.salesProvider.allSales
        .where((sale) => sale.status == 'completed' && !sale.isReturn)
        .toList();

    final Map<String, ProductSalesData> tempMap = {};

    for (var sale in completedSales) {
      final items = await widget.salesProvider.getSaleItems(sale.id);
      for (var item in items) {
        if (tempMap.containsKey(item.productId)) {
          // Find product details for unit conversion
          final product = widget.salesProvider.products
              .where((p) => p.id == item.productId)
              .firstOrNull;
          final productBaseUnit = product?.unit ?? item.unit;
          tempMap[item.productId]!.addSale(item.quantity, item.unit, productBaseUnit, item.totalPrice);
        } else {
          // Find product details
          final product = widget.salesProvider.products
              .where((p) => p.id == item.productId)
              .firstOrNull;

          // Convert initial quantity to base unit
          final productBaseUnit = product?.unit ?? item.unit;
          final quantityInBaseUnit = UnitConverter.convertUnit(item.quantity, item.unit, productBaseUnit);

          tempMap[item.productId] = ProductSalesData(
            productId: item.productId,
            productName: product?.name ?? 'Unknown Product',
            category: product?.categoryId ?? 'Unknown',
            totalQuantitySold: quantityInBaseUnit,
            totalRevenue: item.totalPrice,
          );
        }
      }
    }

    setState(() {
      productSalesMap = tempMap;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Top Products Report'),
          backgroundColor: Colors.orange[600],
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final sortedProducts = productSalesMap.values.toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Top Products Report'),
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
      ),
      body: sortedProducts.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No product sales data available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedProducts.length,
              itemBuilder: (context, index) {
                final product = sortedProducts[index];
                final rank = index + 1;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getRankColor(
                        rank,
                      ).withValues(alpha: 0.2),
                      child: Text(
                        '#$rank',
                        style: TextStyle(
                          color: _getRankColor(rank),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      product.productName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${product.category} • ${product.totalQuantitySold} units sold',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${product.totalRevenue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '\$${product.averagePrice.toStringAsFixed(2)}/unit',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey;
      case 3:
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }
}

// Customer Analysis Report Screen
class CustomerAnalysisReportScreen extends StatefulWidget {
  final SalesProvider salesProvider;

  const CustomerAnalysisReportScreen({super.key, required this.salesProvider});

  @override
  State<CustomerAnalysisReportScreen> createState() =>
      _CustomerAnalysisReportScreenState();
}

class _CustomerAnalysisReportScreenState
    extends State<CustomerAnalysisReportScreen> {
  Map<String, CustomerSalesData> customerSalesMap = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateCustomerAnalysis();
  }

  Future<void> _calculateCustomerAnalysis() async {
    final completedSales = widget.salesProvider.allSales
        .where((sale) => sale.status == 'completed' && !sale.isReturn)
        .toList();

    final Map<String, CustomerSalesData> tempMap = {};

    for (var sale in completedSales) {
      if (tempMap.containsKey(sale.customerId)) {
        tempMap[sale.customerId]!.addSale(sale.totalAmount, sale.createdAt);
      } else {
        // Find customer details
        final customer = widget.salesProvider.customers
            .where((c) => c.id == sale.customerId)
            .firstOrNull;

        tempMap[sale.customerId] = CustomerSalesData(
          customerId: sale.customerId,
          customerName: customer?.name ?? 'Unknown Customer',
          customerEmail: customer?.email ?? '',
          totalSpent: sale.totalAmount,
          totalTransactions: 1,
          lastPurchaseDate: sale.createdAt,
        );
      }
    }

    setState(() {
      customerSalesMap = tempMap;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Customer Analysis Report'),
          backgroundColor: Colors.purple[600],
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final sortedCustomers = customerSalesMap.values.toList()
      ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Customer Analysis Report'),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
      ),
      body: sortedCustomers.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No customer data available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedCustomers.length,
              itemBuilder: (context, index) {
                final customer = sortedCustomers[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple[100],
                      child: Text(
                        customer.customerName.isNotEmpty
                            ? customer.customerName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: Colors.purple[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      customer.customerName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${customer.totalTransactions} transactions'),
                        Text(
                          'Last purchase: ${DateFormat('MMM dd, yyyy').format(customer.lastPurchaseDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${customer.totalSpent.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '\$${customer.averageOrderValue.toStringAsFixed(2)}/order',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}

// Data classes for reports
class ProductSalesData {
  final String productId;
  final String productName;
  final String category;
  double totalQuantitySold;
  double totalRevenue;

  ProductSalesData({
    required this.productId,
    required this.productName,
    required this.category,
    required this.totalQuantitySold,
    required this.totalRevenue,
  });

  void addSale(double quantity, String itemUnit, String productBaseUnit, double revenue) {
    // Convert quantity to base unit before adding
    final quantityInBaseUnit = UnitConverter.convertUnit(quantity, itemUnit, productBaseUnit);
    totalQuantitySold += quantityInBaseUnit;
    totalRevenue += revenue;
  }

  double get averagePrice =>
      totalQuantitySold > 0 ? totalRevenue / totalQuantitySold : 0;
}

class CustomerSalesData {
  final String customerId;
  final String customerName;
  final String customerEmail;
  double totalSpent;
  int totalTransactions;
  DateTime lastPurchaseDate;

  CustomerSalesData({
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.totalSpent,
    required this.totalTransactions,
    required this.lastPurchaseDate,
  });

  void addSale(double amount, DateTime date) {
    totalSpent += amount;
    totalTransactions++;
    if (date.isAfter(lastPurchaseDate)) {
      lastPurchaseDate = date;
    }
  }

  double get averageOrderValue =>
      totalTransactions > 0 ? totalSpent / totalTransactions : 0;
}
