import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/connectivity_service.dart';
import '../../widgets/connectivity_wrapper.dart';
import 'barcode_scanner_screen.dart';

class AddUpdateProductScreen extends StatefulWidget {
  final ProductModel? product; // null for add, ProductModel for update
  final bool canEdit;

  const AddUpdateProductScreen({super.key, this.product, this.canEdit = true});

  @override
  State<AddUpdateProductScreen> createState() => _AddUpdateProductScreenState();
}

class _AddUpdateProductScreenState extends State<AddUpdateProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _currentStockController;
  late final TextEditingController _minimumStockController;
  late final TextEditingController _brandController;
  late final TextEditingController _barcodeController;

  // Selected values
  String? _selectedCategoryId;
  String? _selectedVendorId;

  // Loading state
  bool _isSubmitting = false;

  // Common units for products
  static const List<String> _commonUnits = [
    'kg',
    'g',
    'pcs',
    'dozen',
    'ml',
    'L',
  ];

  bool get _isEditMode => widget.product != null;

  // Barcode validation helper
  String? _validateBarcode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Barcode is optional
    }

    final barcode = value.trim();

    // Check minimum length
    if (barcode.length < 8) {
      return 'Barcode must be at least 8 digits';
    }

    // Check maximum length (most barcodes are 8-14 digits)
    if (barcode.length > 14) {
      return 'Barcode cannot exceed 14 digits';
    }

    // Check if contains only numbers
    if (!RegExp(r'^[0-9]+$').hasMatch(barcode)) {
      return 'Barcode must contain only numbers';
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadInitialData();
  }

  void _initializeControllers() {
    final product = widget.product;

    _nameController = TextEditingController(text: product?.name ?? '');
    _unitController = TextEditingController(text: product?.unit ?? '');
    _purchasePriceController = TextEditingController(
      text: product?.purchasePrice.toString() ?? '',
    );
    _salePriceController = TextEditingController(
      text: product?.salePrice.toString() ?? '',
    );
    _currentStockController = TextEditingController(
      text: product?.currentStock.toStringAsFixed(2) ?? '',
    );
    _minimumStockController = TextEditingController(
      text: product?.minimumStockLevel.toStringAsFixed(2) ?? '',
    );
    _brandController = TextEditingController(text: product?.brand ?? '');
    _barcodeController = TextEditingController(text: product?.barcode ?? '');

    _selectedCategoryId = product?.categoryId;
    _selectedVendorId = product?.vendorId;
  }

  void _loadInitialData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categoryProvider = Provider.of<CategoryProvider>(
        context,
        listen: false,
      );
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Start listening to categories
      categoryProvider.startListening();

      // Load vendors if not already loaded
      if (userProvider.getActiveUsersByRole('vendor').isEmpty) {
        userProvider.loadUsersByRole('vendor');
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _currentStockController.dispose();
    _minimumStockController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConnectivityWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditMode ? 'Update Product' : 'Add Product'),
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          actions: [
            if (widget.canEdit)
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        if (!ConnectivityService().isConnected) {
                          ConnectivityService.showNoInternetDialog(
                            context,
                            onRetry: _submitForm,
                          );
                          return;
                        }
                        _submitForm();
                      },
                child: Text(
                  _isEditMode ? 'UPDATE' : 'SAVE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildProductNameField(),
                const SizedBox(height: 16),
                _buildUnitField(),
                const SizedBox(height: 16),
                _buildPriceFields(),
                const SizedBox(height: 16),
                _buildStockFields(),
                const SizedBox(height: 16),
                _buildBrandField(),
                const SizedBox(height: 16),
                _buildBarcodeField(),
                const SizedBox(height: 16),
                _buildCategoryField(),
                const SizedBox(height: 16),
                _buildVendorField(),
                const SizedBox(height: 32),
                if (widget.canEdit) _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductNameField() {
    return TextFormField(
      controller: _nameController,
      enabled: widget.canEdit,
      decoration: const InputDecoration(
        labelText: 'Product Name *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.inventory),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Product name is required';
        }
        return null;
      },
    );
  }

  Widget _buildUnitField() {
    return DropdownButtonFormField<String>(
      value: _unitController.text.isEmpty ? null : _unitController.text,
      decoration: const InputDecoration(
        labelText: 'Select Unit *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.straighten),
      ),
      isExpanded: true,
      menuMaxHeight: 300,
      items: _commonUnits.map((unit) {
        return DropdownMenuItem<String>(
          value: unit,
          child: Text(unit, style: const TextStyle(fontSize: 16)),
        );
      }).toList(),
      onChanged: widget.canEdit
          ? (value) {
              setState(() {
                _unitController.text = value ?? '';
              });
            }
          : null,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a unit';
        }
        return null;
      },
    );
  }

  Widget _buildPriceFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _purchasePriceController,
            enabled: widget.canEdit,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Purchase Price *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.attach_money),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Purchase price is required';
              }
              final price = double.tryParse(value);
              if (price == null || price < 0) {
                return 'Enter valid price';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: _salePriceController,
            enabled: widget.canEdit,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Sale Price *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.sell),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Sale price is required';
              }
              final price = double.tryParse(value);
              if (price == null || price < 0) {
                return 'Enter valid price';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStockFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _currentStockController,
            enabled: widget.canEdit,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Current Stock *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.inventory_2),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Current stock is required';
              }
              final stock = double.tryParse(value);
              if (stock == null || stock < 0) {
                return 'Enter valid stock';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: _minimumStockController,
            enabled: widget.canEdit,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Minimum Stock *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.warning),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Minimum stock is required';
              }
              final stock = double.tryParse(value);
              if (stock == null || stock < 0) {
                return 'Enter valid stock';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBrandField() {
    return TextFormField(
      controller: _brandController,
      enabled: widget.canEdit,
      decoration: const InputDecoration(
        labelText: 'Brand (Optional)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.branding_watermark),
      ),
    );
  }

  Widget _buildBarcodeField() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _barcodeController,
            enabled: widget.canEdit,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Barcode (Optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.qr_code),
              hintText: 'Enter or scan barcode',
              helperText: 'Barcode must be unique if provided',
            ),
            validator: _validateBarcode,
            onChanged: widget.canEdit
                ? (value) {
                    // Clear any previous barcode validation errors when user types
                    if (value.trim().isEmpty) {
                      setState(() {});
                    }
                  }
                : null,
          ),
        ),
        if (widget.canEdit) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: _scanBarcode,
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Barcode',
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue[100],
              foregroundColor: Colors.blue[600],
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryField() {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, child) {
        if (categoryProvider.isLoading) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(4),
              color: Colors.blue[50],
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text(
                  'Loading categories...',
                  style: TextStyle(color: Colors.blue),
                ),
              ],
            ),
          );
        }

        final productCategories = _getProductCategories(
          categoryProvider.categories,
        );

        if (productCategories.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orange),
              borderRadius: BorderRadius.circular(4),
              color: Colors.orange[50],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'No Categories Available',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please create categories first.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        }

        return DropdownButtonFormField<String>(
          value: _selectedCategoryId,
          decoration: const InputDecoration(
            labelText: 'Select Category *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category),
          ),
          items: productCategories.map((category) {
            return DropdownMenuItem<String>(
              value: category.id,
              child: Text(category.name, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: widget.canEdit
              ? (value) {
                  setState(() {
                    _selectedCategoryId = value;
                  });
                }
              : null,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a category';
            }
            return null;
          },
        );
      },
    );
  }

  Widget _buildVendorField() {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        if (userProvider.isLoading) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(4),
              color: Colors.blue[50],
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text(
                  'Loading vendors...',
                  style: TextStyle(color: Colors.blue),
                ),
              ],
            ),
          );
        }

        final vendors = userProvider.getActiveUsersByRole('vendor');

        if (vendors.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orange),
              borderRadius: BorderRadius.circular(4),
              color: Colors.orange[50],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'No Vendors Available',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please create vendor accounts first.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        }

        return DropdownButtonFormField<String>(
          value: _selectedVendorId,
          decoration: const InputDecoration(
            labelText: 'Select Vendor *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.business),
          ),
          items: vendors.map((vendor) {
            return DropdownMenuItem<String>(
              value: vendor.id,
              child: Text(
                vendor.company != null
                    ? '${vendor.name}(${vendor.company!})'
                    : vendor.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            );
          }).toList(),
          onChanged: widget.canEdit
              ? (value) {
                  setState(() {
                    _selectedVendorId = value;
                  });
                }
              : null,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a vendor';
            }
            return null;
          },
        );
      },
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSubmitting ? null : _submitForm,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: _isSubmitting
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Processing...'),
              ],
            )
          : Text(
              _isEditMode ? 'UPDATE PRODUCT' : 'CREATE PRODUCT',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }

  List<CategoryModel> _getProductCategories(List<CategoryModel> allCategories) {
    final activeCategories = allCategories.where((c) => c.isActive).toList();
    return activeCategories.where((category) {
      final hasSubcategories = allCategories.any(
        (c) => c.parentCategory == category.id,
      );
      return !hasSubcategories;
    }).toList();
  }

  void _scanBarcode() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
      );

      if (result != null && result is String && result.isNotEmpty) {
        _barcodeController.text = result;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Barcode scanned: $result'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      _showManualBarcodeEntry();
    }
  }

  void _showManualBarcodeEntry() {
    final manualController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Barcode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Camera not available. Enter barcode manually:'),
            const SizedBox(height: 16),
            TextField(
              controller: manualController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Barcode',
                border: OutlineInputBorder(),
                hintText: 'Enter barcode number',
                prefixIcon: Icon(Icons.qr_code),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final barcode = manualController.text.trim();
              if (barcode.isNotEmpty) {
                _barcodeController.text = barcode;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Barcode added: $barcode'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );

      // Check barcode uniqueness if barcode is provided
      final barcode = _barcodeController.text.trim();
      if (barcode.isNotEmpty) {
        final isUnique = await productProvider.isBarcodeUnique(
          barcode,
          excludeProductId: _isEditMode ? widget.product!.id : null,
        );

        if (!isUnique) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Barcode "$barcode" is already used by another product',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          setState(() {
            _isSubmitting = false;
          });
          return;
        }
      }

      // Check for similar products to prevent duplicates
      final productName = _nameController.text.trim();
      final similarProducts = await productProvider.findSimilarProducts(
        productName,
        _selectedCategoryId!,
        excludeProductId: _isEditMode ? widget.product!.id : null,
      );

      if (similarProducts.isNotEmpty && mounted) {
        final shouldContinue = await _showSimilarProductsDialog(
          similarProducts,
        );
        if (!shouldContinue) {
          setState(() {
            _isSubmitting = false;
          });
          return;
        }
      }

      final product = ProductModel(
        id: _isEditMode ? widget.product!.id : '',
        name: _nameController.text.trim(),
        unit: _unitController.text,
        purchasePrice: double.parse(_purchasePriceController.text),
        salePrice: double.parse(_salePriceController.text),
        currentStock: double.parse(_currentStockController.text),
        categoryId: _selectedCategoryId!,
        vendorId: _selectedVendorId!,
        minimumStockLevel: double.parse(_minimumStockController.text),
        createdAt: _isEditMode ? widget.product!.createdAt : DateTime.now(),
        isActive: _isEditMode ? widget.product!.isActive : true,
        updatedAt: DateTime.now(),
        brand: _brandController.text.trim().isEmpty
            ? null
            : _brandController.text.trim(),
        barcode: barcode.isEmpty ? null : barcode,
      );

      bool success;
      if (_isEditMode) {
        success = await productProvider.updateProduct(
          widget.product!.id,
          product,
        );
      } else {
        success = await productProvider.createProduct(product);
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? 'Product updated successfully!'
                  : 'Product created successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              productProvider.error ??
                  (_isEditMode
                      ? 'Failed to update product'
                      : 'Failed to create product'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<bool> _showSimilarProductsDialog(
    List<ProductModel> similarProducts,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(child: Text('Similar Products Found', maxLines: 2)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Found ${similarProducts.length} similar product${similarProducts.length > 1 ? 's' : ''}:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Column(
                      children: similarProducts
                          .map(
                            (product) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (product.barcode != null)
                                    Text('Barcode: ${product.barcode}'),
                                  Text(
                                    'Price: \$${product.salePrice.toStringAsFixed(2)}',
                                  ),
                                  Text('Stock: ${product.currentStock}'),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Do you want to continue creating this product?',
                  style: TextStyle(color: Colors.orange),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
