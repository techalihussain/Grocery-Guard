import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/user_provider.dart';
import 'add_update_product_screen.dart';
import 'bulk_add_products_screen.dart';
import 'stock_ledger_screen.dart';
import 'view_product_screen.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  String _searchQuery = '';
  String _selectedFilter =
      'all'; // all, active, inactive, low_stock, out_of_stock
  String? _selectedCategoryId; // For category filtering
  UserModel? _currentUser;
  final TextEditingController _searchController = TextEditingController();

  // Map to track local toggle states for immediate UI feedback
  final Map<String, bool> _localToggleStates = {};

  // Set to track locally deleted products for immediate UI feedback
  final Set<String> _locallyDeletedProducts = {};

  // Listeners for providers
  VoidCallback? _productProviderListener;
  VoidCallback? _categoryProviderListener;
  VoidCallback? _userProviderListener;

  // Provider references to avoid accessing them in dispose
  ProductProvider? _productProvider;
  CategoryProvider? _categoryProvider;
  UserProvider? _userProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentUser();
      _initializeProductProvider();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();

    // Remove all listeners using stored provider references to prevent widget access errors
    if (_productProviderListener != null && _productProvider != null) {
      _productProvider!.removeListener(_productProviderListener!);
    }
    if (_categoryProviderListener != null && _categoryProvider != null) {
      _categoryProvider!.removeListener(_categoryProviderListener!);
    }
    if (_userProviderListener != null && _userProvider != null) {
      _userProvider!.removeListener(_userProviderListener!);
    }

    super.dispose();
  }

  // Load current user to check role
  void _loadCurrentUser() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (authProvider.user != null) {
      final user = await userProvider.getUserById(authProvider.user!.uid);
      // Check if widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    }
  }

  // Initialize product provider
  void _initializeProductProvider() async {
    _productProvider = Provider.of<ProductProvider>(context, listen: false);
    _categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);

    try {
      // Initialize product provider
      await _productProvider!.initialize();

      // Initialize category provider - start listening to all categories (active and inactive)
      // so we can always display category names even when categories are deactivated
      _categoryProvider!.startListening();

      // Load all vendors from 'users' collection where role = 'vendor'
      await _userProvider!.loadUsersByRole('vendor');

      // Also load all users to ensure we have the complete user data
      await _userProvider!.loadAllUsers();

      // Create and store listeners - avoid context access to prevent widget lifecycle errors
      _productProviderListener = () {
        if (_productProvider != null && _productProvider!.hasError && mounted) {
          // Just log the error instead of showing snackBar to avoid widget lifecycle issues
          debugPrint('Product Provider Error: ${_productProvider!.error}');
          // The UI will show errors through Consumer widgets instead
        }
      };

      _categoryProviderListener = () {
        if (_categoryProvider != null &&
            _categoryProvider!.error != null &&
            mounted) {
          // Just log the error instead of showing snackBar to avoid widget lifecycle issues
          debugPrint('Category Provider Error: ${_categoryProvider!.error}');
          // The UI will show errors through Consumer widgets instead
        }
      };

      _userProviderListener = () {
        if (_userProvider != null && _userProvider!.error != null && mounted) {
          // Just log the error instead of showing snackBar to avoid widget lifecycle issues
          debugPrint('User Provider Error: ${_userProvider!.error}');
          // The UI will show errors through Consumer widgets instead
        }
      };

      // Add the listeners
      _productProvider!.addListener(_productProviderListener!);
      _categoryProvider!.addListener(_categoryProviderListener!);
      _userProvider!.addListener(_userProviderListener!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Initialization Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Search products
  void _searchProducts(String query) {
    setState(() {
      _searchQuery = query;
    });

    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );

    // Check if there are any products at all before searching
    if (productProvider.products.isEmpty && query.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No products available. Please create products first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    productProvider.searchProducts(query);
  }

  // Change filter
  void _changeFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  // Change category filter
  void _changeCategoryFilter(String? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
  }

  // Get categories that can have products (leaf categories - no subcategories)
  List<CategoryModel> _getProductCategories(List<CategoryModel> allCategories) {
    final activeCategories = allCategories.where((c) => c.isActive).toList();

    // Filter to show only categories that can have products assigned to them
    // These are categories that don't have any subcategories (leaf categories)
    return activeCategories.where((category) {
      // Check if this category has any subcategories
      final hasSubcategories = allCategories.any(
        (c) => c.parentCategory == category.id,
      );
      // Only show categories that don't have subcategories
      return !hasSubcategories;
    }).toList();
  }

  // Permission methods
  bool _canCreateProduct() {
    if (_currentUser == null) return false;
    return _currentUser!.role == 'admin' || _currentUser!.role == 'storeuser';
  }

  bool _canEditProduct() {
    if (_currentUser == null) return false;
    return _currentUser!.role == 'admin' || _currentUser!.role == 'storeuser';
  }

  bool _canDeleteProduct() {
    if (_currentUser == null) return false;
    return _currentUser!.role == 'admin';
  }

  bool _canToggleStatus() {
    if (_currentUser == null) return false;
    return _currentUser!.role == 'admin' || _currentUser!.role == 'storeuser';
  }

  bool _canManageStock() {
    if (_currentUser == null) return false;
    return _currentUser!.role == 'admin' || _currentUser!.role == 'storeuser';
  }

  // Navigate to add product screen
  void _navigateToAddProduct() async {
    if (!_canCreateProduct()) {
      _showPermissionDeniedMessage('create products');
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddUpdateProductScreen()),
    );

    // Refresh the product list if a product was added
    if (result == true && mounted) {
      // The product provider will automatically update via stream
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product list updated'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // Navigate to bulk add products screen
  void _navigateToBulkAddProducts() async {
    if (!_canCreateProduct()) {
      _showPermissionDeniedMessage('create products');
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BulkAddProductsScreen()),
    );

    // Refresh the product list if products were added
    if (result == true && mounted) {
      // The product provider will automatically update via stream
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Products added successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Navigate to edit product screen
  void _navigateToEditProduct(ProductModel product) async {
    if (!_canEditProduct()) {
      _showPermissionDeniedMessage('edit products');
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddUpdateProductScreen(product: product, canEdit: true),
      ),
    );

    // Refresh the product list if a product was updated
    if (result == true && mounted) {
      // The product provider will automatically update via stream
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product updated successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // Navigate to view product screen
  void _navigateToViewProduct(ProductModel product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewProductScreen(product: product),
      ),
    );
  }

  // Navigate to stock ledger screen
  void _navigateToStockLedger(ProductModel product) async {
    if (_currentUser?.role != 'admin') {
      _showPermissionDeniedMessage('view stock ledger');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StockLedgerScreen(product: product),
      ),
    );
  }

  // Toggle product status
  void _toggleProductStatus(ProductModel product) async {
    if (!_canToggleStatus()) {
      _showPermissionDeniedMessage('change product status');
      return;
    }

    final newStatus = !product.isActive;

    // If trying to activate product, check if category is active
    if (newStatus == true) {
      final categoryProvider = Provider.of<CategoryProvider>(
        context,
        listen: false,
      );
      final category = categoryProvider.categories
          .where((c) => c.id == product.categoryId)
          .firstOrNull;

      if (category == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot activate product: Category not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!category.isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot activate "${product.name}": First activate the category "${category.name}"',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Go to Categories',
              textColor: Colors.white,
              onPressed: () {
                // Could navigate to category screen or show category management
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please go to Categories section to activate the category first',
                    ),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
            ),
          ),
        );
        return;
      }
    }

    // Update local state immediately for UI feedback
    if (mounted) {
      setState(() {
        _localToggleStates[product.id] = newStatus;
      });
    }

    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );

    final updatedProduct = product.copyWith(
      isActive: newStatus,
      updatedAt: DateTime.now(),
    );

    final success = await productProvider.updateProduct(
      product.id,
      updatedProduct,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${product.name} ${newStatus ? 'activated' : 'deactivated'} successfully!',
          ),
          backgroundColor: newStatus ? Colors.green : Colors.orange,
        ),
      );
    } else {
      // Revert local state if operation failed
      if (mounted) {
        setState(() {
          _localToggleStates[product.id] = product.isActive;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change status: ${productProvider.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Remove from local state once stream updates (after a delay)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _localToggleStates.remove(product.id);
        });
      }
    });
  }

  // Show delete confirmation
  void _showDeleteConfirmation(ProductModel product) {
    if (!_canDeleteProduct()) {
      _showPermissionDeniedMessage('delete products');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete "${product.name}"?',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red[600], size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Warning:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'This action will permanently remove the product from the database. This cannot be undone!',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _deleteProduct(product),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  // Delete product (permanent removal from database)
  void _deleteProduct(ProductModel product) async {
    Navigator.pop(context); // Close dialog

    // Add to locally deleted set immediately for UI feedback
    setState(() {
      _locallyDeletedProducts.add(product.id);
    });

    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );

    final success = await productProvider.deleteProduct(product.id);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} deleted permanently!'),
          backgroundColor: Colors.green,
        ),
      );

      // Remove from local set after stream updates (after a delay)
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _locallyDeletedProducts.remove(product.id);
          });
        }
      });
    } else {
      // Remove from local set if deletion failed
      setState(() {
        _locallyDeletedProducts.remove(product.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete product: ${productProvider.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show stock management dialog
  void _showStockManagementDialog(ProductModel product) {
    if (!_canManageStock()) {
      _showPermissionDeniedMessage('manage stock');
      return;
    }

    final quantityController = TextEditingController();
    String operation = 'add'; // add or reduce

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Manage Stock - ${product.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Current stock info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Current Stock: ${product.currentStock.toStringAsFixed(2)} ${product.unit}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Operation selection
                  Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('Add Stock'),
                        value: 'add',
                        groupValue: operation,
                        onChanged: (value) {
                          setState(() {
                            operation = value!;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Reduce Stock'),
                        value: 'reduce',
                        groupValue: operation,
                        onChanged: (value) {
                          setState(() {
                            operation = value!;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quantity input
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(
                        operation == 'add' ? Icons.add : Icons.remove,
                        color: operation == 'add' ? Colors.green : Colors.red,
                      ),
                      suffixText: product.unit,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _updateStock(
                  product,
                  int.tryParse(quantityController.text) ?? 0,
                  operation,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: operation == 'add'
                      ? Colors.green
                      : Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text(operation == 'add' ? 'Add Stock' : 'Reduce Stock'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Update stock with manual adjustment tracking
  void _updateStock(
    ProductModel product,
    int quantity,
    String operation,
  ) async {
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pop(context); // Close dialog

    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );

    // Use manual stock adjustment which will record in ledger
    final success = await productProvider.manualStockAdjustment(
      productId: product.id,
      change: quantity,
      createdBy: _currentUser?.name ?? 'Unknown User',
      isAddition: operation == 'add',
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${operation == 'add' ? 'Added' : 'Reduced'} $quantity ${product.unit} ${operation == 'add' ? 'to' : 'from'} ${product.name}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update stock: ${productProvider.error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show permission denied message
  void _showPermissionDeniedMessage(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('You don\'t have permission to $action'),
        backgroundColor: Colors.orange,
        action: SnackBarAction(
          label: 'Contact Admin',
          textColor: Colors.white,
          onPressed: () {
            // Could open contact admin dialog or navigate to help
          },
        ),
      ),
    );
  }

  // Get filtered products based on current filter
  List<ProductModel> _getFilteredProducts(List<ProductModel> products) {
    List<ProductModel> filtered = products;

    // Filter out locally deleted products
    filtered = filtered
        .where((product) => !_locallyDeletedProducts.contains(product.id))
        .toList();

    // Apply category filter if selected
    if (_selectedCategoryId != null) {
      filtered = filtered
          .where((product) => product.categoryId == _selectedCategoryId)
          .toList();
    }

    switch (_selectedFilter) {
      case 'active':
        filtered = filtered.where((p) => p.isActive).toList();
        break;
      case 'inactive':
        filtered = filtered.where((p) => !p.isActive).toList();
        break;
      case 'low_stock':
        filtered = filtered
            .where(
              (p) =>
                  p.isActive &&
                  p.currentStock <= p.minimumStockLevel &&
                  p.currentStock > 0,
            )
            .toList();
        break;
      case 'out_of_stock':
        filtered = filtered
            .where((p) => p.isActive && p.currentStock == 0)
            .toList();
        break;
      case 'all':
      default:
        // No additional filtering
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Products',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Only show add options for admin and storeuser
          if (_canCreateProduct())
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'single':
                    _navigateToAddProduct();
                    break;
                  case 'bulk':
                    _navigateToBulkAddProducts();
                    break;
                }
              },
              icon: const Icon(Icons.add),
              tooltip: 'Add Products',
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'single',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Add Single Product'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'bulk',
                  child: Row(
                    children: [
                      Icon(Icons.add_box, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Bulk Add Products'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _searchProducts,
              decoration: InputDecoration(
                labelText: 'Search Products',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Active', 'active'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Inactive', 'inactive'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Low Stock', 'low_stock'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Out of Stock', 'out_of_stock'),
                  const SizedBox(width: 8),
                  // Category Filter Chip
                  _buildCategoryFilterChip(),
                ],
              ),
            ),
          ),

          // Role Info Banner (for salesman)
          if (_currentUser?.role == 'salesman')
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'You have view-only access. Contact admin for changes.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

          // Stock Summary Cards
          Consumer<ProductProvider>(
            builder: (context, productProvider, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Products',
                        productProvider.totalProducts.toString(),
                        Icons.inventory,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSummaryCard(
                        'Low Stock',
                        productProvider.lowStockCount.toString(),
                        Icons.warning,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSummaryCard(
                        'Out of Stock',
                        productProvider.outOfStockCount.toString(),
                        Icons.error,
                        Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Products List
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, productProvider, child) {
                final filteredProducts = _getFilteredProducts(
                  productProvider.filteredProducts,
                );

                return productProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty && _selectedFilter == 'all'
                                  ? 'No products found'
                                  : 'No products match your criteria',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (_searchQuery.isNotEmpty ||
                                _selectedFilter != 'all')
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Try adjusting your search or filter',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return _buildProductCard(product);
                        },
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Build filter chip
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _changeFilter(value);
        }
      },
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue[600],
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue[600] : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  // Build category filter chip
  Widget _buildCategoryFilterChip() {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, child) {
        if (categoryProvider.isLoading) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Loading...', style: TextStyle(fontSize: 12)),
              ],
            ),
          );
        }

        final productCategories = _getProductCategories(
          categoryProvider.categories,
        );

        if (productCategories.isEmpty) {
          return const SizedBox.shrink();
        }

        return PopupMenuButton<String?>(
          onSelected: (categoryId) {
            _changeCategoryFilter(categoryId);
          },
          itemBuilder: (context) {
            return [
              PopupMenuItem<String?>(
                value: null,
                child: Row(
                  children: [
                    Icon(
                      Icons.clear,
                      size: 16,
                      color: _selectedCategoryId == null
                          ? Colors.blue[600]
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'All Categories',
                      style: TextStyle(
                        color: _selectedCategoryId == null
                            ? Colors.blue[600]
                            : Colors.grey[600],
                        fontWeight: _selectedCategoryId == null
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              ...productCategories.map((category) {
                final isSelected = _selectedCategoryId == category.id;
                return PopupMenuItem<String?>(
                  value: category.id,
                  child: Row(
                    children: [
                      Icon(
                        Icons.category,
                        size: 16,
                        color: isSelected ? Colors.blue[600] : Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          category.name,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.blue[600]
                                : Colors.grey[600],
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ];
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _selectedCategoryId != null
                  ? Colors.blue[100]
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _selectedCategoryId != null
                    ? Colors.blue[300]!
                    : Colors.grey[300]!,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.category,
                  size: 16,
                  color: _selectedCategoryId != null
                      ? Colors.blue[600]
                      : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  _selectedCategoryId != null
                      ? productCategories
                            .firstWhere((c) => c.id == _selectedCategoryId)
                            .name
                      : 'Category',
                  style: TextStyle(
                    color: _selectedCategoryId != null
                        ? Colors.blue[600]
                        : Colors.grey[600],
                    fontWeight: _selectedCategoryId != null
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                // Show clear button when category is selected, dropdown arrow otherwise
                if (_selectedCategoryId != null) ...[
                  GestureDetector(
                    onTap: () => _changeCategoryFilter(null),
                    child: Icon(Icons.close, size: 16, color: Colors.blue[600]),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: _selectedCategoryId != null
                      ? Colors.blue[600]
                      : Colors.grey[600],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Build summary card
  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
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
      ),
    );
  }

  // Build product card
  Widget _buildProductCard(ProductModel product) {
    final isOutOfStock = product.currentStock <= 0;
    final isLowStock =
        product.currentStock > 0 &&
        product.currentStock <= product.minimumStockLevel;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showProductActions(product),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Product Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: product.isActive ? Colors.blue[100] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory,
                  color: product.isActive ? Colors.blue[600] : Colors.grey[600],
                  size: 28,
                ),
              ),

              const SizedBox(width: 16),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Category and Stock Status
                    Consumer<CategoryProvider>(
                      builder: (context, categoryProvider, child) {
                        final category = categoryProvider.categories
                            .where((c) => c.id == product.categoryId)
                            .firstOrNull;

                        return Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    category?.name ?? 'Unknown Category',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  if (category != null &&
                                      !category.isActive) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.orange[300]!,
                                        ),
                                      ),
                                      child: Text(
                                        'INACTIVE',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isOutOfStock)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'OUT OF STOCK',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[700],
                                  ),
                                ),
                              )
                            else if (isLowStock)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'LOW STOCK',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Status Toggle/Indicator
              if (_canToggleStatus())
                Consumer<CategoryProvider>(
                  builder: (context, categoryProvider, child) {
                    final category = categoryProvider.categories
                        .where((c) => c.id == product.categoryId)
                        .firstOrNull;

                    final canActivate = category?.isActive ?? false;
                    final currentValue =
                        _localToggleStates.containsKey(product.id)
                        ? _localToggleStates[product.id]!
                        : product.isActive;

                    return Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: currentValue,
                        onChanged: (value) {
                          // If trying to activate but category is inactive, show tooltip
                          if (value == true && !canActivate) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Cannot activate: Category "${category?.name ?? 'Unknown'}" is inactive',
                                ),
                                backgroundColor: Colors.orange,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          _toggleProductStatus(product);
                        },
                        activeColor: Colors.green,
                        inactiveThumbColor: !canActivate && !currentValue
                            ? Colors.orange
                            : Colors.red,
                        inactiveTrackColor: !canActivate && !currentValue
                            ? Colors.orange.withValues(alpha: 0.3)
                            : Colors.red.withValues(alpha: 0.3),
                        activeTrackColor: Colors.green.withValues(alpha: 0.3),
                      ),
                    );
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: product.isActive ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: product.isActive
                          ? Colors.green[200]!
                          : Colors.red[200]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: product.isActive ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        product.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 12,
                          color: product.isActive
                              ? Colors.green[800]
                              : Colors.red[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Show product actions bottom sheet
  void _showProductActions(ProductModel product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Product info header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: product.isActive
                            ? Colors.blue[100]
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.inventory,
                        color: product.isActive
                            ? Colors.blue[600]
                            : Colors.grey[600],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${product.currentStock.toStringAsFixed(2)} ${product.unit} • \$${product.salePrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // View Product Details (Available to all users)
                    _buildActionTile(
                      icon: Icons.info_outline,
                      title: 'View Product Details',
                      subtitle: 'See complete product information',
                      color: Colors.green,
                      onTap: () {
                        Navigator.pop(context);
                        _navigateToViewProduct(product);
                      },
                    ),

                    // Manage Stock (Admin and Store User only, and only for active products)
                    if (_canManageStock() && product.isActive)
                      _buildActionTile(
                        icon: Icons.inventory_2,
                        title: 'Manage Stock',
                        subtitle: 'Add or reduce product stock',
                        color: Colors.blue,
                        onTap: () {
                          Navigator.pop(context);
                          _showStockManagementDialog(product);
                        },
                      ),

                    // View Stock Ledger (Admin only)
                    if (_currentUser?.role == 'admin')
                      _buildActionTile(
                        icon: Icons.history,
                        title: 'View Stock Ledger',
                        subtitle: 'See manual stock adjustment history',
                        color: Colors.purple,
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToStockLedger(product);
                        },
                      ),

                    // Show message for inactive products - stock management
                    if (_canManageStock() && !product.isActive)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.block, color: Colors.blue[600]),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Stock cannot be managed for inactive products. Activate the product first to manage stock.',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Edit Product (Admin and Store User only, and only for active products)
                    if (_canEditProduct() && product.isActive)
                      _buildActionTile(
                        icon: Icons.edit,
                        title: 'Edit Product',
                        subtitle: 'Change product information',
                        color: Colors.orange,
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToEditProduct(product);
                        },
                      ),

                    // Show message for inactive products
                    if (_canEditProduct() && !product.isActive)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.block, color: Colors.orange[600]),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Inactive products cannot be edited. Activate the product first to make changes.',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Delete Product (Admin only)
                    if (_canDeleteProduct())
                      _buildActionTile(
                        icon: Icons.delete,
                        title: 'Delete Product',
                        subtitle: 'Permanently remove product',
                        color: Colors.red,
                        onTap: () {
                          Navigator.pop(context);
                          _showDeleteConfirmation(product);
                        },
                      ),

                    // View Only message for Salesman
                    if (_currentUser?.role == 'salesman')
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[600]),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'You have view-only access to products',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[600], fontSize: 14),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
