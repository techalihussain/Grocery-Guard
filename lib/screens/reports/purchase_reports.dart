import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:untitled/models/purchase_model.dart';
import 'package:untitled/providers/purchase_provider.dart';
import 'package:untitled/utils/responsive_utils.dart';

class PurchaseReports extends StatefulWidget {
  const PurchaseReports({super.key});

  @override
  State<PurchaseReports> createState() => _PurchaseReportsState();
}

class _PurchaseReportsState extends State<PurchaseReports> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );
    await purchaseProvider.loadAllPurchases();
    await purchaseProvider.loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Purchase Reports",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(context.responsivePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Purchase Analytics Dashboard',
              style: ResponsiveUtils.getResponsiveTextStyle(
                context,
                baseSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Monitor procurement and vendor performance',
              style: ResponsiveUtils.getResponsiveTextStyle(
                context,
                baseSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Consumer<PurchaseProvider>(
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
                            'Error loading purchase data',
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

                  return GridView.count(
                    crossAxisCount: context.isTablet ? 2 : 1,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: context.isTablet ? 1.5 : 2.5,
                    children: [
                      _buildReportCard(
                        title: 'Purchase Orders',
                        subtitle: 'Track all purchase orders and their status',
                        icon: Icons.receipt_long,
                        color: Colors.indigo,
                        onTap: () => _showPurchaseOrdersReport(
                          purchaseProvider.allPurchases,
                        ),
                      ),
                      _buildReportCard(
                        title: 'Vendor Performance',
                        subtitle: 'Analyze vendor delivery and quality metrics',
                        icon: Icons.business,
                        color: Colors.teal,
                        onTap: () =>
                            _showVendorPerformanceReport(purchaseProvider),
                      ),
                      _buildReportCard(
                        title: 'Cost Analysis',
                        subtitle: 'Purchase cost trends and budget analysis',
                        icon: Icons.analytics,
                        color: Colors.red,
                        onTap: () => _showCostAnalysisReport(
                          purchaseProvider.allPurchases,
                        ),
                      ),
                      _buildReportCard(
                        title: 'Purchase Returns',
                        subtitle: 'Track returned items and refund processing',
                        icon: Icons.assignment_return,
                        color: Colors.orange,
                        onTap: () => _showPurchaseReturnsReport(
                          purchaseProvider.allPurchases,
                        ),
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

  void _showPurchaseOrdersReport(List<PurchaseModel> allPurchases) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PurchaseOrdersReportScreen(purchases: allPurchases),
      ),
    );
  }

  void _showVendorPerformanceReport(PurchaseProvider purchaseProvider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            VendorPerformanceReportScreen(purchaseProvider: purchaseProvider),
      ),
    );
  }

  void _showCostAnalysisReport(List<PurchaseModel> allPurchases) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CostAnalysisReportScreen(purchases: allPurchases),
      ),
    );
  }

  void _showPurchaseReturnsReport(List<PurchaseModel> allPurchases) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PurchaseReturnsReportScreen(purchases: allPurchases),
      ),
    );
  }
}

// Purchase Orders Report Screen
class PurchaseOrdersReportScreen extends StatelessWidget {
  final List<PurchaseModel> purchases;

  const PurchaseOrdersReportScreen({super.key, required this.purchases});

  @override
  Widget build(BuildContext context) {
    final completedPurchases = purchases
        .where(
          (purchase) => purchase.status == 'completed' && !purchase.isReturn,
        )
        .toList();

    final draftPurchases = purchases
        .where((purchase) => purchase.status == 'drafted')
        .toList();

    // Group purchases by date
    final Map<String, List<PurchaseModel>> purchasesByDate = {};
    for (var purchase in completedPurchases) {
      final dateKey = DateFormat('yyyy-MM-dd').format(purchase.createdAt);
      purchasesByDate[dateKey] = (purchasesByDate[dateKey] ?? [])
        ..add(purchase);
    }

    // Sort dates in descending order
    final sortedDates = purchasesByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Purchase Orders Report'),
        backgroundColor: Colors.indigo[600],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Summary Cards
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Completed Orders',
                    completedPurchases.length.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Draft Orders',
                    draftPurchases.length.toString(),
                    Icons.edit_note,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Value',
                    '\$${completedPurchases.fold<double>(0, (sum, p) => sum + p.totalAmount).toStringAsFixed(0)}',
                    Icons.attach_money,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          // Purchase Orders List
          Expanded(
            child: sortedDates.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No purchase orders available',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sortedDates.length,
                    itemBuilder: (context, index) {
                      final date = sortedDates[index];
                      final dayPurchases = purchasesByDate[date]!;
                      final totalAmount = dayPurchases.fold<double>(
                        0,
                        (sum, purchase) => sum + purchase.totalAmount,
                      );
                      final totalOrders = dayPurchases.length;

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
                            '$totalOrders orders • \$${totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          children: dayPurchases
                              .map(
                                (purchase) => ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: purchase.isCredit
                                        ? Colors.orange[100]
                                        : Colors.green[100],
                                    child: Icon(
                                      purchase.isCredit
                                          ? Icons.credit_card
                                          : Icons.payments,
                                      color: purchase.isCredit
                                          ? Colors.orange
                                          : Colors.green,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text('Invoice: ${purchase.invoiceNo}'),
                                  subtitle: Text(
                                    '${purchase.paymentMethod.toUpperCase()} • ${DateFormat('HH:mm').format(purchase.createdAt)}',
                                  ),
                                  trailing: Text(
                                    '\$${purchase.totalAmount.toStringAsFixed(2)}',
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
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Vendor Performance Report Screen
class VendorPerformanceReportScreen extends StatefulWidget {
  final PurchaseProvider purchaseProvider;

  const VendorPerformanceReportScreen({
    super.key,
    required this.purchaseProvider,
  });

  @override
  State<VendorPerformanceReportScreen> createState() =>
      _VendorPerformanceReportScreenState();
}

class _VendorPerformanceReportScreenState
    extends State<VendorPerformanceReportScreen> {
  Map<String, VendorPerformanceData> vendorPerformanceMap = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateVendorPerformance();
  }

  Future<void> _calculateVendorPerformance() async {
    final completedPurchases = widget.purchaseProvider.allPurchases
        .where(
          (purchase) => purchase.status == 'completed' && !purchase.isReturn,
        )
        .toList();

    final Map<String, VendorPerformanceData> tempMap = {};

    for (var purchase in completedPurchases) {
      if (tempMap.containsKey(purchase.vendorId)) {
        tempMap[purchase.vendorId]!.addPurchase(
          purchase.totalAmount,
          purchase.createdAt,
        );
      } else {
        // Find vendor details
        final vendor = widget.purchaseProvider.vendors
            .where((v) => v.id == purchase.vendorId)
            .firstOrNull;

        tempMap[purchase.vendorId] = VendorPerformanceData(
          vendorId: purchase.vendorId,
          vendorName: vendor?.name ?? 'Unknown Vendor',
          vendorEmail: vendor?.email ?? '',
          totalSpent: purchase.totalAmount,
          totalOrders: 1,
          lastOrderDate: purchase.createdAt,
        );
      }
    }

    setState(() {
      vendorPerformanceMap = tempMap;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Vendor Performance Report'),
          backgroundColor: Colors.teal[600],
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final sortedVendors = vendorPerformanceMap.values.toList()
      ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Vendor Performance Report'),
        backgroundColor: Colors.teal[600],
        foregroundColor: Colors.white,
      ),
      body: sortedVendors.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No vendor data available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedVendors.length,
              itemBuilder: (context, index) {
                final vendor = sortedVendors[index];
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
                      vendor.vendorName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${vendor.totalOrders} orders'),
                        Text(
                          'Last order: ${DateFormat('MMM dd, yyyy').format(vendor.lastOrderDate)}',
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
                          '\$${vendor.totalSpent.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '\$${vendor.averageOrderValue.toStringAsFixed(2)}/order',
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

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey;
      case 3:
        return Colors.brown;
      default:
        return Colors.teal;
    }
  }
}

// Cost Analysis Report Screen
class CostAnalysisReportScreen extends StatelessWidget {
  final List<PurchaseModel> purchases;

  const CostAnalysisReportScreen({super.key, required this.purchases});

  @override
  Widget build(BuildContext context) {
    final completedPurchases = purchases
        .where(
          (purchase) => purchase.status == 'completed' && !purchase.isReturn,
        )
        .toList();

    // Group purchases by month
    final Map<String, List<PurchaseModel>> purchasesByMonth = {};
    for (var purchase in completedPurchases) {
      final monthKey = DateFormat('yyyy-MM').format(purchase.createdAt);
      purchasesByMonth[monthKey] = (purchasesByMonth[monthKey] ?? [])
        ..add(purchase);
    }

    // Sort months in descending order
    final sortedMonths = purchasesByMonth.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Cost Analysis Report'),
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
      ),
      body: sortedMonths.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No cost data available',
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
                final monthPurchases = purchasesByMonth[month]!;
                final totalCost = monthPurchases.fold<double>(
                  0,
                  (sum, purchase) => sum + purchase.totalAmount,
                );
                final totalOrders = monthPurchases.length;
                final avgOrderValue = totalCost / totalOrders;

                // Calculate cash vs credit breakdown
                final cashPurchases = monthPurchases
                    .where((p) => !p.isCredit)
                    .length;
                final creditPurchases = monthPurchases
                    .where((p) => p.isCredit)
                    .length;

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
                                'Total Cost',
                                '\$${totalCost.toStringAsFixed(2)}',
                                Icons.attach_money,
                                Colors.red,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricCard(
                                'Orders',
                                totalOrders.toString(),
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
                                'Avg Order',
                                '\$${avgOrderValue.toStringAsFixed(2)}',
                                Icons.trending_up,
                                Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricCard(
                                'Cash/Credit',
                                '$cashPurchases/$creditPurchases',
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

// Purchase Returns Report Screen
class PurchaseReturnsReportScreen extends StatelessWidget {
  final List<PurchaseModel> purchases;

  const PurchaseReturnsReportScreen({super.key, required this.purchases});

  @override
  Widget build(BuildContext context) {
    final returnPurchases = purchases
        .where((purchase) => purchase.isReturn)
        .toList();

    // Group returns by date
    final Map<String, List<PurchaseModel>> returnsByDate = {};
    for (var returnPurchase in returnPurchases) {
      final dateKey = DateFormat('yyyy-MM-dd').format(returnPurchase.createdAt);
      returnsByDate[dateKey] = (returnsByDate[dateKey] ?? [])
        ..add(returnPurchase);
    }

    // Sort dates in descending order
    final sortedDates = returnsByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final totalReturns = returnPurchases.length;
    final totalReturnValue = returnPurchases.fold<double>(
      0,
      (sum, purchase) => sum + purchase.totalAmount.abs(),
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Purchase Returns Report'),
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Summary Cards
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Returns',
                    totalReturns.toString(),
                    Icons.assignment_return,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Return Value',
                    '\$${totalReturnValue.toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Avg Return',
                    totalReturns > 0
                        ? '\$${(totalReturnValue / totalReturns).toStringAsFixed(2)}'
                        : '\$0.00',
                    Icons.trending_down,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          // Returns List
          Expanded(
            child: sortedDates.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_return,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No purchase returns found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sortedDates.length,
                    itemBuilder: (context, index) {
                      final date = sortedDates[index];
                      final dayReturns = returnsByDate[date]!;
                      final totalAmount = dayReturns.fold<double>(
                        0,
                        (sum, purchase) => sum + purchase.totalAmount.abs(),
                      );

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
                            '${dayReturns.length} returns • \$${totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          children: dayReturns
                              .map(
                                (returnPurchase) => ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.red[100],
                                    child: const Icon(
                                      Icons.assignment_return,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    'Return: ${returnPurchase.invoiceNo}',
                                  ),
                                  subtitle: Text(
                                    'Original ID: ${returnPurchase.originalId ?? 'N/A'} • ${DateFormat('HH:mm').format(returnPurchase.createdAt)}',
                                  ),
                                  trailing: Text(
                                    '\$${returnPurchase.totalAmount.abs().toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Data class for vendor performance
class VendorPerformanceData {
  final String vendorId;
  final String vendorName;
  final String vendorEmail;
  double totalSpent;
  int totalOrders;
  DateTime lastOrderDate;

  VendorPerformanceData({
    required this.vendorId,
    required this.vendorName,
    required this.vendorEmail,
    required this.totalSpent,
    required this.totalOrders,
    required this.lastOrderDate,
  });

  void addPurchase(double amount, DateTime date) {
    totalSpent += amount;
    totalOrders++;
    if (date.isAfter(lastOrderDate)) {
      lastOrderDate = date;
    }
  }

  double get averageOrderValue =>
      totalOrders > 0 ? totalSpent / totalOrders : 0;
}
