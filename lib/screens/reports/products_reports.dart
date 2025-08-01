import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:untitled/models/product_model.dart';
import 'package:untitled/providers/product_provider.dart';
import 'package:untitled/providers/purchase_provider.dart';
import 'package:untitled/providers/sales_provider.dart';
import 'package:untitled/utils/responsive_utils.dart';
import 'package:untitled/utils/unit_converter.dart';

class ProductReports extends StatefulWidget {
  const ProductReports({super.key});

  @override
  State<ProductReports> createState() => _ProductReportsState();
}

class _ProductReportsState extends State<ProductReports> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );

    await Future.wait([
      productProvider.initialize(),
      salesProvider.loadAllSales(),
      purchaseProvider.loadAllPurchases(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Product Reports",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(context.responsivePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inventory & Product Analytics',
              style: ResponsiveUtils.getResponsiveTextStyle(
                context,
                baseSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track inventory levels and product performance',
              style: ResponsiveUtils.getResponsiveTextStyle(
                context,
                baseSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child:
                  Consumer3<ProductProvider, SalesProvider, PurchaseProvider>(
                    builder:
                        (
                          context,
                          productProvider,
                          salesProvider,
                          purchaseProvider,
                          child,
                        ) {
                          if (productProvider.isLoading ||
                              salesProvider.isLoading ||
                              purchaseProvider.isLoading) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (productProvider.error != null ||
                              salesProvider.error != null ||
                              purchaseProvider.error != null) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error,
                                    size: 64,
                                    color: Colors.red[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Error loading product data',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    productProvider.error ??
                                        salesProvider.error ??
                                        purchaseProvider.error ??
                                        '',
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
                                title: 'Stock Levels',
                                subtitle:
                                    'Current inventory levels and stock alerts',
                                icon: Icons.inventory,
                                color: Colors.green,
                                onTap: () => _showStockLevelsReport(
                                  productProvider.products,
                                ),
                              ),
                              _buildReportCard(
                                title: 'Low Stock Alert',
                                subtitle: 'Products running low on inventory',
                                icon: Icons.warning,
                                color: Colors.red,
                                onTap: () => _showLowStockAlert(
                                  productProvider.products,
                                ),
                              ),
                              _buildReportCard(
                                title: 'Product Movement',
                                subtitle:
                                    'Track product sales and movement patterns',
                                icon: Icons.trending_up,
                                color: Colors.blue,
                                onTap: () => _showProductMovementReport(
                                  salesProvider,
                                  purchaseProvider,
                                  productProvider.products,
                                ),
                              ),
                              _buildReportCard(
                                title: 'Profit Margins',
                                subtitle: 'Analyze profit margins by product',
                                icon: Icons.attach_money,
                                color: Colors.teal,
                                onTap: () => _showProfitMarginsReport(
                                  productProvider.products,
                                  salesProvider,
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

  void _showStockLevelsReport(List<ProductModel> products) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StockLevelsReportScreen(products: products),
      ),
    );
  }

  void _showLowStockAlert(List<ProductModel> products) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LowStockAlertScreen(products: products),
      ),
    );
  }

  void _showProductMovementReport(
    SalesProvider salesProvider,
    PurchaseProvider purchaseProvider,
    List<ProductModel> products,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductMovementReportScreen(
          salesProvider: salesProvider,
          purchaseProvider: purchaseProvider,
          products: products,
        ),
      ),
    );
  }

  void _showProfitMarginsReport(
    List<ProductModel> products,
    SalesProvider salesProvider,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfitMarginsReportScreen(
          products: products,
          salesProvider: salesProvider,
        ),
      ),
    );
  }
}

// Stock Levels Report Screen
class StockLevelsReportScreen extends StatelessWidget {
  final List<ProductModel> products;

  const StockLevelsReportScreen({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    final activeProducts = products.where((p) => p.isActive).toList();

    // Sort by stock level (lowest first)
    activeProducts.sort((a, b) => a.currentStock.compareTo(b.currentStock));

    // Calculate stock statistics
    final totalProducts = activeProducts.length;
    final totalStockValue = activeProducts.fold<double>(
      0,
      (sum, product) => sum + (product.currentStock * product.salePrice),
    );
    final averageStock = totalProducts > 0
        ? activeProducts.fold<double>(
                0,
                (sum, product) => sum + product.currentStock,
              ) /
              totalProducts
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Stock Levels Report'),
        backgroundColor: Colors.green[600],
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
                    'Total Products',
                    totalProducts.toString(),
                    Icons.inventory,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Stock Value',
                    '\$${totalStockValue.toStringAsFixed(0)}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Avg Stock',
                    averageStock.toStringAsFixed(0),
                    Icons.trending_up,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          // Products List
          Expanded(
            child: activeProducts.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No products found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: activeProducts.length,
                    itemBuilder: (context, index) {
                      final product = activeProducts[index];
                      final stockStatus = _getStockStatus(
                        product.currentStock,
                        product.minimumStockLevel,
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: stockStatus.color.withValues(
                              alpha: 0.2,
                            ),
                            child: Icon(
                              stockStatus.icon,
                              color: stockStatus.color,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Unit: ${product.unit}'),
                              Text('Min Stock: ${product.minimumStockLevel}'),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${product.currentStock}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: stockStatus.color,
                                ),
                              ),
                              Text(
                                stockStatus.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: stockStatus.color,
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
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

  StockStatus _getStockStatus(double currentStock, double minStock) {
    if (currentStock == 0) {
      return StockStatus('Out of Stock', Icons.error, Colors.red);
    } else if (currentStock <= minStock) {
      return StockStatus('Low Stock', Icons.warning, Colors.orange);
    } else if (currentStock <= minStock * 2) {
      return StockStatus('Medium', Icons.info, Colors.blue);
    } else {
      return StockStatus('Good', Icons.check_circle, Colors.green);
    }
  }
}

// Low Stock Alert Screen
class LowStockAlertScreen extends StatelessWidget {
  final List<ProductModel> products;

  const LowStockAlertScreen({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    final lowStockProducts = products
        .where(
          (product) =>
              product.isActive &&
              product.currentStock <= product.minimumStockLevel,
        )
        .toList();

    final outOfStockProducts = lowStockProducts
        .where((p) => p.currentStock == 0)
        .toList();
    final criticalStockProducts = lowStockProducts
        .where((p) => p.currentStock > 0)
        .toList();

    // Sort by urgency (out of stock first, then by current stock ascending)
    lowStockProducts.sort((a, b) {
      if (a.currentStock == 0 && b.currentStock > 0) return -1;
      if (a.currentStock > 0 && b.currentStock == 0) return 1;
      return a.currentStock.compareTo(b.currentStock);
    });

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Low Stock Alert'),
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Alert Summary
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildAlertCard(
                    'Out of Stock',
                    outOfStockProducts.length.toString(),
                    Icons.error,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAlertCard(
                    'Critical Stock',
                    criticalStockProducts.length.toString(),
                    Icons.warning,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAlertCard(
                    'Total Alerts',
                    lowStockProducts.length.toString(),
                    Icons.notifications,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          // Low Stock Products List
          Expanded(
            child: lowStockProducts.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 64, color: Colors.green),
                        SizedBox(height: 16),
                        Text(
                          'All products are well stocked!',
                          style: TextStyle(fontSize: 18, color: Colors.green),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: lowStockProducts.length,
                    itemBuilder: (context, index) {
                      final product = lowStockProducts[index];
                      final isOutOfStock = product.currentStock == 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: isOutOfStock
                            ? Colors.red[50]
                            : Colors.orange[50],
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isOutOfStock
                                ? Colors.red[100]
                                : Colors.orange[100],
                            child: Icon(
                              isOutOfStock ? Icons.error : Icons.warning,
                              color: isOutOfStock ? Colors.red : Colors.orange,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Unit: ${product.unit}'),
                              Text('Min Stock: ${product.minimumStockLevel}'),
                              Text(
                                isOutOfStock
                                    ? 'URGENT: Restock immediately'
                                    : 'Restock soon',
                                style: TextStyle(
                                  color: isOutOfStock
                                      ? Colors.red
                                      : Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${product.currentStock}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isOutOfStock
                                      ? Colors.red
                                      : Colors.orange,
                                ),
                              ),
                              Text(
                                isOutOfStock ? 'OUT' : 'LOW',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOutOfStock
                                      ? Colors.red
                                      : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(
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
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

// Product Movement Report Screen
class ProductMovementReportScreen extends StatefulWidget {
  final SalesProvider salesProvider;
  final PurchaseProvider purchaseProvider;
  final List<ProductModel> products;

  const ProductMovementReportScreen({
    super.key,
    required this.salesProvider,
    required this.purchaseProvider,
    required this.products,
  });

  @override
  State<ProductMovementReportScreen> createState() =>
      _ProductMovementReportScreenState();
}

class _ProductMovementReportScreenState
    extends State<ProductMovementReportScreen> {
  Map<String, ProductMovementData> productMovementMap = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateProductMovement();
  }

  Future<void> _calculateProductMovement() async {
    final Map<String, ProductMovementData> tempMap = {};

    // Initialize with all products
    for (var product in widget.products) {
      if (product.isActive) {
        tempMap[product.id] = ProductMovementData(
          productId: product.id,
          productName: product.name,
          unit: product.unit,
          currentStock: product.currentStock,
          totalSold: 0,
          totalPurchased: 0,
        );
      }
    }

    // Calculate sales data
    final completedSales = widget.salesProvider.allSales
        .where((sale) => sale.status == 'completed' && !sale.isReturn)
        .toList();

    for (var sale in completedSales) {
      final items = await widget.salesProvider.getSaleItems(sale.id);
      for (var item in items) {
        if (tempMap.containsKey(item.productId)) {
          tempMap[item.productId]!.addSale(item.quantity, item.unit);
        }
      }
    }

    // Calculate purchase data
    final completedPurchases = widget.purchaseProvider.allPurchases
        .where(
          (purchase) => purchase.status == 'completed' && !purchase.isReturn,
        )
        .toList();

    for (var purchase in completedPurchases) {
      final items = await widget.purchaseProvider.getPurchaseItems(purchase.id);
      for (var item in items) {
        if (tempMap.containsKey(item.productId)) {
          tempMap[item.productId]!.addPurchase(item.quantity, item.unit);
        }
      }
    }

    setState(() {
      productMovementMap = tempMap;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Product Movement Report'),
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final sortedProducts = productMovementMap.values.toList()
      ..sort((a, b) => b.totalSold.compareTo(a.totalSold));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Product Movement Report'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: sortedProducts.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.trending_up, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No movement data available',
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

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.productName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Unit: ${product.unit}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMovementMetric(
                                'Current Stock',
                                product.currentStock.toStringAsFixed(2),
                                Icons.inventory,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMovementMetric(
                                'Total Sold',
                                product.totalSold.toString(),
                                Icons.trending_down,
                                Colors.red,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMovementMetric(
                                'Total Purchased',
                                product.totalPurchased.toString(),
                                Icons.trending_up,
                                Colors.green,
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

  Widget _buildMovementMetric(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
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
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Profit Margins Report Screen
class ProfitMarginsReportScreen extends StatefulWidget {
  final List<ProductModel> products;
  final SalesProvider salesProvider;

  const ProfitMarginsReportScreen({
    super.key,
    required this.products,
    required this.salesProvider,
  });

  @override
  State<ProfitMarginsReportScreen> createState() =>
      _ProfitMarginsReportScreenState();
}

class _ProfitMarginsReportScreenState extends State<ProfitMarginsReportScreen> {
  Map<String, ProfitMarginData> profitMarginMap = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateProfitMargins();
  }

  Future<void> _calculateProfitMargins() async {
    final Map<String, ProfitMarginData> tempMap = {};

    // Initialize with all products
    for (var product in widget.products) {
      if (product.isActive) {
        final profitPerUnit = product.salePrice - product.purchasePrice;
        final profitMarginPercent = product.salePrice > 0
            ? (profitPerUnit / product.salePrice) * 100
            : 0.0;

        tempMap[product.id] = ProfitMarginData(
          productId: product.id,
          productName: product.name,
          unit: product.unit,
          purchasePrice: product.purchasePrice,
          salePrice: product.salePrice,
          profitPerUnit: profitPerUnit,
          profitMarginPercent: profitMarginPercent,
          totalSold: 0,
          totalProfit: 0,
        );
      }
    }

    // Calculate actual sales and profits
    final completedSales = widget.salesProvider.allSales
        .where((sale) => sale.status == 'completed' && !sale.isReturn)
        .toList();

    for (var sale in completedSales) {
      final items = await widget.salesProvider.getSaleItems(sale.id);
      for (var item in items) {
        if (tempMap.containsKey(item.productId)) {
          final product = widget.products
              .where((p) => p.id == item.productId)
              .firstOrNull;

          if (product != null) {
            // Convert quantity to base unit for accurate profit calculation
            final quantityInBaseUnit = UnitConverter.convertToBaseUnit(item.quantity, item.unit);
            final profitPerUnit = product.salePrice - product.purchasePrice;
            tempMap[item.productId]!.addSale(
              quantityInBaseUnit,
              profitPerUnit * quantityInBaseUnit,
            );
          }
        }
      }
    }

    setState(() {
      profitMarginMap = tempMap;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profit Margins Report'),
          backgroundColor: Colors.teal[600],
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final sortedProducts = profitMarginMap.values.toList()
      ..sort((a, b) => b.profitMarginPercent.compareTo(a.profitMarginPercent));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Profit Margins Report'),
        backgroundColor: Colors.teal[600],
        foregroundColor: Colors.white,
      ),
      body: sortedProducts.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.attach_money, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No profit data available',
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
                final marginColor = _getMarginColor(
                  product.profitMarginPercent,
                );

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product.productName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: marginColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${product.profitMarginPercent.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: marginColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Unit: ${product.unit}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildProfitMetric(
                                'Purchase',
                                '\$${product.purchasePrice.toStringAsFixed(2)}',
                                Icons.money_off,
                                Colors.red,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildProfitMetric(
                                'Sale',
                                '\$${product.salePrice.toStringAsFixed(2)}',
                                Icons.attach_money,
                                Colors.green,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildProfitMetric(
                                'Profit/Unit',
                                '\$${product.profitPerUnit.toStringAsFixed(2)}',
                                Icons.trending_up,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildProfitMetric(
                                'Total Profit',
                                '\$${product.totalProfit.toStringAsFixed(2)}',
                                Icons.account_balance_wallet,
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

  Widget _buildProfitMetric(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getMarginColor(double marginPercent) {
    if (marginPercent < 10) {
      return Colors.red;
    } else if (marginPercent < 25) {
      return Colors.orange;
    } else if (marginPercent < 50) {
      return Colors.blue;
    } else {
      return Colors.green;
    }
  }
}

// Data classes for reports
class StockStatus {
  final String label;
  final IconData icon;
  final Color color;

  StockStatus(this.label, this.icon, this.color);
}

class ProductMovementData {
  final String productId;
  final String productName;
  final String unit;
  final double currentStock;
  double totalSold;
  double totalPurchased;

  ProductMovementData({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.currentStock,
    required this.totalSold,
    required this.totalPurchased,
  });

  void addSale(double quantity, String itemUnit) {
    // Convert quantity to base unit before adding
    final quantityInBaseUnit = UnitConverter.convertToBaseUnit(quantity, itemUnit);
    totalSold += quantityInBaseUnit;
  }

  void addPurchase(double quantity, String itemUnit) {
    // Convert quantity to base unit before adding
    final quantityInBaseUnit = UnitConverter.convertToBaseUnit(quantity, itemUnit);
    totalPurchased += quantityInBaseUnit;
  }
}

class ProfitMarginData {
  final String productId;
  final String productName;
  final String unit;
  final double purchasePrice;
  final double salePrice;
  final double profitPerUnit;
  final double profitMarginPercent;
  double totalSold;
  double totalProfit;

  ProfitMarginData({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.purchasePrice,
    required this.salePrice,
    required this.profitPerUnit,
    required this.profitMarginPercent,
    required this.totalSold,
    required this.totalProfit,
  });

  void addSale(double quantity, double profit) {
    totalSold += quantity;
    totalProfit += profit;
  }
}
