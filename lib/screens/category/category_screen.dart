import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/user_provider.dart';
import 'view_category_screen.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, active, inactive
  UserModel? _currentUser;
  final TextEditingController _searchController = TextEditingController();

  // Map to track local toggle states for immediate UI feedback
  final Map<String, bool> _localToggleStates = {};

  // Set to track locally deleted categories for immediate UI feedback
  final Set<String> _locallyDeletedCategories = {};

  // Listener for category provider
  VoidCallback? _categoryProviderListener;

  // Provider reference to avoid accessing it in dispose
  CategoryProvider? _categoryProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentUser();
      _startCategoryStream();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();

    // Remove the listener and stop the category stream using stored provider reference
    if (_categoryProviderListener != null && _categoryProvider != null) {
      _categoryProvider!.removeListener(_categoryProviderListener!);
    }

    // Stop the category stream
    if (_categoryProvider != null) {
      _categoryProvider!.stopListening();
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

  // Start category stream
  void _startCategoryStream() {
    _categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    _categoryProvider!.startListening();

    // Create and store the listener - avoid context access to prevent widget lifecycle errors
    _categoryProviderListener = () {
      if (_categoryProvider != null &&
          _categoryProvider!.error != null &&
          mounted) {
        // Just log the error instead of showing snackBar to avoid widget lifecycle issues
        debugPrint('Category Provider Error: ${_categoryProvider!.error}');
        _categoryProvider!.clearError();
        // The UI will show errors through Consumer widgets instead
      }
    };

    // Add the listener
    _categoryProvider!.addListener(_categoryProviderListener!);
  }

  // Search categories
  void _searchCategories(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  // Change filter
  void _changeFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  // Check if user can create categories
  bool _canCreateCategory() {
    if (_currentUser == null) return false;
    return _currentUser!.role == 'admin' || _currentUser!.role == 'storeuser';
  }

  // Check if user can edit categories
  bool _canEditCategory() {
    if (_currentUser == null) return false;
    return _currentUser!.role == 'admin' || _currentUser!.role == 'storeuser';
  }

  // Check if user can delete categories
  bool _canDeleteCategory() {
    if (_currentUser == null) return false;
    return _currentUser!.role == 'admin'; // Only admin can delete
  }

  // Check if user can activate/deactivate categories
  bool _canToggleStatus() {
    if (_currentUser == null) return false;
    return _currentUser!.role == 'admin' || _currentUser!.role == 'storeuser';
  }

  // Show add category dialog
  void _showAddCategoryDialog() {
    if (!_canCreateCategory()) {
      _showPermissionDeniedMessage('create categories');
      return;
    }

    _showCategoryTypeSelectionDialog();
  }

  // Show category type selection dialog
  void _showCategoryTypeSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'What type of category would you like to create?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            // Parent Category Option
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.category, color: Colors.blue[600]),
                ),
                title: const Text('Parent Category'),
                subtitle: const Text('Create a main category'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateParentCategoryDialog();
                },
              ),
            ),

            const SizedBox(height: 8),

            // Subcategory Option
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.subdirectory_arrow_right,
                    color: Colors.green[600],
                  ),
                ),
                title: const Text('Subcategory'),
                subtitle: const Text('Create a category under a parent'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateSubcategoryDialog();
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Show create parent category dialog
  void _showCreateParentCategoryDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Parent Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This will be a main category that can have subcategories.',
                      style: TextStyle(fontSize: 12),
                    ),
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
            onPressed: () => _createParentCategory(nameController.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // Show create subcategory dialog
  void _showCreateSubcategoryDialog() {
    final nameController = TextEditingController();
    String? selectedParentId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create Subcategory'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Subcategory Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.subdirectory_arrow_right),
                  ),
                ),
                const SizedBox(height: 16),

                // Parent Category Dropdown
                Consumer<CategoryProvider>(
                  builder: (context, categoryProvider, child) {
                    // Filter parent categories: only show those with 0 products and no subcategories
                    final allParentCategories = categoryProvider.categories
                        .where((c) => c.parentCategory == null && c.isActive)
                        .toList();

                    return FutureBuilder<List<CategoryModel>>(
                      future: _getValidParentCategories(
                        allParentCategories,
                        categoryProvider,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final validParentCategories = snapshot.data ?? [];

                        if (validParentCategories.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_outlined,
                                  color: Colors.orange[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'No available parent categories. Only categories with 0 products can have subcategories.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return DropdownButtonFormField<String>(
                          value: selectedParentId,
                          decoration: const InputDecoration(
                            labelText: 'Select Parent Category',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: validParentCategories.map((category) {
                            final categoryProvider =
                                Provider.of<CategoryProvider>(
                                  context,
                                  listen: false,
                                );
                            final subcategoryCount = categoryProvider
                                .getSubcategoriesCountSync(category.id);

                            return DropdownMenuItem<String>(
                              value: category.id,
                              child: Text(
                                subcategoryCount > 0
                                    ? '${category.name} ($subcategoryCount)'
                                    : category.name,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedParentId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a parent category';
                            }
                            return null;
                          },
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.green[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'This subcategory will be grouped under the selected parent category.',
                          style: TextStyle(fontSize: 12),
                        ),
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
                onPressed: selectedParentId != null
                    ? () => _createSubcategory(
                        nameController.text.trim(),
                        selectedParentId!,
                      )
                    : null,
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Create parent category
  void _createParentCategory(String name) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Category name cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pop(context); // Close dialog

    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );

    final newCategory = CategoryModel(
      id: '',
      name: name,
      isActive: true,
      createdAt: DateTime.now(),
      lastModifiedBy: _currentUser?.id,
      createdBy: _currentUser?.id,
      parentCategory: null, // This is a parent category
    );

    final success = await categoryProvider.createCategory(newCategory);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Parent category created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to create parent category: ${categoryProvider.error}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Create subcategory
  void _createSubcategory(String name, String parentId) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subcategory name cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pop(context); // Close dialog

    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );

    final newCategory = CategoryModel(
      id: '',
      name: name,
      isActive: true,
      createdAt: DateTime.now(),
      lastModifiedBy: _currentUser?.id,
      createdBy: _currentUser?.id,
      parentCategory: parentId, // This is a subcategory
    );

    final success = await categoryProvider.createCategory(newCategory);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subcategory created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to create subcategory: ${categoryProvider.error}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show edit category dialog
  void _showEditCategoryDialog(CategoryModel category) {
    if (!_canEditCategory()) {
      _showPermissionDeniedMessage('edit categories');
      return;
    }

    final nameController = TextEditingController(text: category.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                _updateCategory(category, nameController.text.trim()),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  // Update category
  void _updateCategory(CategoryModel category, String newName) async {
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Category name cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pop(context); // Close dialog

    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );

    final updatedCategory = category.copyWith(
      name: newName,
      lastModifiedBy: _currentUser?.id,
      updatedAt: DateTime.now(),
    );

    final success = await categoryProvider.updateCategory(updatedCategory);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Category updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update category: ${categoryProvider.error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Toggle category status (activate/deactivate)
  void _toggleCategoryStatus(CategoryModel category) async {
    if (!_canToggleStatus()) {
      _showPermissionDeniedMessage('change category status');
      return;
    }

    final newStatus = !category.isActive;

    // If trying to activate a subcategory, check if parent category is active
    if (newStatus == true && category.parentCategory != null) {
      final categoryProvider = Provider.of<CategoryProvider>(
        context,
        listen: false,
      );
      final parentCategory = categoryProvider.categories
          .where((c) => c.id == category.parentCategory)
          .firstOrNull;

      if (parentCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot activate subcategory: Parent category not found',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!parentCategory.isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot activate "${category.name}": First activate the parent category "${parentCategory.name}"',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Got it',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Please activate "${parentCategory.name}" first, then try activating "${category.name}"',
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
        _localToggleStates[category.id] = newStatus;
      });
    }

    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );
    bool success;

    if (category.isActive) {
      success = await categoryProvider.deactivateCategory(
        category.id,
        _currentUser?.id ?? 'system',
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${category.name} deactivated successfully!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      success = await categoryProvider.activateCategory(
        category.id,
        _currentUser?.id ?? 'system',
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${category.name} activated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    if (!success) {
      // Revert local state if operation failed
      if (mounted) {
        setState(() {
          _localToggleStates[category.id] = category.isActive;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to change status: ${categoryProvider.error}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Remove from local state once stream updates (after a delay)
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _localToggleStates.remove(category.id);
          });
        }
      });
    }
  }

  // Show delete confirmation
  void _showDeleteConfirmation(CategoryModel category) {
    if (!_canDeleteCategory()) {
      _showPermissionDeniedMessage('delete categories');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${category.name}"?'),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _deleteCategory(category),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Delete category
  void _deleteCategory(CategoryModel category) async {
    Navigator.pop(context); // Close dialog

    // Add to locally deleted set immediately for UI feedback
    setState(() {
      _locallyDeletedCategories.add(category.id);
    });

    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );

    final success = await categoryProvider.deleteCategoryIfEmpty(category.id);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${category.name} deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Remove from local set after stream updates (after a delay)
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _locallyDeletedCategories.remove(category.id);
          });
        }
      });
    } else {
      // Remove from local set if deletion failed
      setState(() {
        _locallyDeletedCategories.remove(category.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not delete the category which contains products or sub categories.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Navigate to view category screen
  void _navigateToViewCategory(CategoryModel category) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewCategoryScreen(category: category),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Categories',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Only show add button for admin and storeuser
          if (_canCreateCategory())
            IconButton(
              onPressed: _showAddCategoryDialog,
              icon: const Icon(Icons.add),
              tooltip: 'Add Category',
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
              onChanged: _searchCategories,
              decoration: InputDecoration(
                labelText: 'Search Categories',
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
                  _buildFilterChip('Parents', 'parents'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Subcategories', 'subcategories'),
                ],
              ),
            ),
          ),

          // Role Info Banner (for salesman)
          if (_currentUser?.role == 'salesman')
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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

          const SizedBox(height: 16),

          // Categories List
          Expanded(
            child: Consumer<CategoryProvider>(
              builder: (context, categoryProvider, child) {
                // Apply filters whenever provider data changes
                List<CategoryModel> filteredCategories = categoryProvider
                    .getFilteredAndSearchedCategories(
                      _selectedFilter,
                      _searchQuery,
                    );

                // Filter out locally deleted categories for immediate UI feedback
                filteredCategories = filteredCategories
                    .where(
                      (category) =>
                          !_locallyDeletedCategories.contains(category.id),
                    )
                    .toList();

                return categoryProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredCategories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.category_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty && _selectedFilter == 'all'
                                  ? 'No categories found'
                                  : 'No categories match your criteria',
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
                        itemCount: filteredCategories.length,
                        itemBuilder: (context, index) {
                          final category = filteredCategories[index];
                          return _buildCategoryCard(category);
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
      selectedColor: Colors.orange[100],
      checkmarkColor: Colors.orange[600],
      labelStyle: TextStyle(
        color: isSelected ? Colors.orange[600] : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  // Simple category card with icon, name, product count, and toggle
  Widget _buildCategoryCard(CategoryModel category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showCategoryActions(category),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Category Icon at start
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: category.isActive
                      ? (category.parentCategory != null
                            ? Colors.green[100]
                            : Colors.orange[100])
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  category.parentCategory != null
                      ? Icons.subdirectory_arrow_right
                      : Icons.category,
                  color: category.isActive
                      ? (category.parentCategory != null
                            ? Colors.green[600]
                            : Colors.orange[600])
                      : Colors.grey[600],
                  size: 28,
                ),
              ),

              const SizedBox(width: 16),

              // Category Name and Product Count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            category.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (category.parentCategory != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Text(
                              'SUB',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Show parent category name if this is a subcategory
                    if (category.parentCategory != null)
                      Consumer<CategoryProvider>(
                        builder: (context, categoryProvider, child) {
                          final parentCategory = categoryProvider.categories
                              .where((c) => c.id == category.parentCategory)
                              .firstOrNull;

                          return Row(
                            children: [
                              Text(
                                'Under: ${parentCategory?.name ?? 'Unknown Parent'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (parentCategory != null &&
                                  !parentCategory.isActive) ...[
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
                                    'PARENT INACTIVE',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),

                    if (category.parentCategory != null)
                      const SizedBox(height: 2),

                    // Dynamic count display: subcategories for parents, products for subcategories
                    FutureBuilder<Map<String, int>>(
                      future: _getDynamicCounts(category),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Text(
                            'Loading...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }

                        final counts =
                            snapshot.data ??
                            {'subcategories': 0, 'products': 0};
                        final subcategoryCount = counts['subcategories'] ?? 0;
                        final productCount = counts['products'] ?? 0;

                        // Show subcategories if this category has any, otherwise show products
                        if (subcategoryCount > 0) {
                          return Text(
                            '$subcategoryCount ${subcategoryCount == 1 ? 'Subcategory' : 'Subcategories'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[600],
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        } else {
                          return Text(
                            '$productCount ${productCount == 1 ? 'Product' : 'Products'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Active/Inactive Toggle Switch at end
              if (_canToggleStatus())
                Consumer<CategoryProvider>(
                  builder: (context, categoryProvider, child) {
                    // Check if this is a subcategory and if parent is active
                    CategoryModel? parentCategory;
                    bool canActivate = true;

                    if (category.parentCategory != null) {
                      parentCategory = categoryProvider.categories
                          .where((c) => c.id == category.parentCategory)
                          .firstOrNull;
                      canActivate = parentCategory?.isActive ?? false;
                    }

                    final currentValue =
                        _localToggleStates.containsKey(category.id)
                        ? _localToggleStates[category.id]!
                        : category.isActive;

                    return Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: currentValue,
                        onChanged: (value) {
                          // If trying to activate subcategory but parent is inactive, show tooltip
                          if (value == true &&
                              category.parentCategory != null &&
                              !canActivate) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Cannot activate: Parent category "${parentCategory?.name ?? 'Unknown'}" is inactive',
                                ),
                                backgroundColor: Colors.orange,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          _toggleCategoryStatus(category);
                        },
                        activeColor: Colors.green,
                        inactiveThumbColor:
                            category.parentCategory != null &&
                                !canActivate &&
                                !currentValue
                            ? Colors.orange
                            : Colors.red,
                        inactiveTrackColor:
                            category.parentCategory != null &&
                                !canActivate &&
                                !currentValue
                            ? Colors.orange.withValues(alpha: 0.3)
                            : Colors.red.withValues(alpha: 0.3),
                        activeTrackColor: Colors.green.withValues(alpha: 0.3),
                      ),
                    );
                  },
                )
              else
                // Show status indicator for users who can't toggle
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: category.isActive
                        ? Colors.green[50]
                        : Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: category.isActive
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
                          color: category.isActive ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        category.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 12,
                          color: category.isActive
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

  // Get valid parent categories (only those with 0 products - subcategories are allowed)
  Future<List<CategoryModel>> _getValidParentCategories(
    List<CategoryModel> parentCategories,
    CategoryProvider categoryProvider,
  ) async {
    final validCategories = <CategoryModel>[];

    for (final category in parentCategories) {
      final productCount = await categoryProvider.getProductCountInCategory(
        category.id,
      );

      // Only show categories with 0 products (subcategories are allowed and encouraged)
      if (productCount == 0) {
        validCategories.add(category);
      }
    }

    return validCategories;
  }

  // Get dynamic counts (subcategories and products) for a category
  Future<Map<String, int>> _getDynamicCounts(CategoryModel category) async {
    try {
      final categoryProvider = Provider.of<CategoryProvider>(
        context,
        listen: false,
      );

      // Get both counts
      final subcategoryCount = await categoryProvider.getSubcategoryCount(
        category.id,
      );
      final productCount = await categoryProvider.getProductCountInCategory(
        category.id,
      );

      return {'subcategories': subcategoryCount, 'products': productCount};
    } catch (e) {
      return {'subcategories': 0, 'products': 0};
    }
  }

  // Show category actions bottom sheet
  void _showCategoryActions(CategoryModel category) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
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

            // Category info header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: category.isActive
                          ? Colors.orange[100]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.category,
                      color: category.isActive
                          ? Colors.orange[600]
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
                          category.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          category.isActive
                              ? 'Active Category'
                              : 'Inactive Category',
                          style: TextStyle(
                            fontSize: 14,
                            color: category.isActive
                                ? Colors.green[600]
                                : Colors.red[600],
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
                  // View Category Action (Available to all users)
                  _buildActionTile(
                    icon: Icons.info_outline,
                    title: 'View Category Details',
                    subtitle: 'See complete category information',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToViewCategory(category);
                    },
                  ),

                  // Edit Action (Admin and Store User only, and only for active categories)
                  if (_canEditCategory() && category.isActive)
                    _buildActionTile(
                      icon: Icons.edit,
                      title: 'Edit Category',
                      subtitle: 'Change category name',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        _showEditCategoryDialog(category);
                      },
                    ),

                  // Show message for inactive categories
                  if (_canEditCategory() && !category.isActive)
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
                              'Inactive categories cannot be edited. Activate the category first to make changes.',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Delete Action (Admin only)
                  if (_canDeleteCategory())
                    _buildActionTile(
                      icon: Icons.delete,
                      title: 'Delete Category',
                      subtitle: 'Permanently remove category',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteConfirmation(category);
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
                              'You have view-only access to categories',
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
