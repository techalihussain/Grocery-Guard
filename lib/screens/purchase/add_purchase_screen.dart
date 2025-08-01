import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../models/product_model.dart';
import '../../models/purchase_model.dart';
import '../../models/sale_purchase_item_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../utils/unit_converter.dart';
import '../../widgets/connectivity_wrapper.dart';

class AddPurchaseScreen extends StatefulWidget {
  const AddPurchaseScreen({super.key});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceController = TextEditingController();
  final _discountController = TextEditingController();
  final _taxController = TextEditingController();

  List<ItemModel> _purchaseItems = [];
  String? _selectedVendorId;
  String _paymentMethod = 'cash';
  bool _isCredit = false;
  double _subtotal = 0.0;
  double _discount = 0.0;
  double _tax = 0.0;
  double _totalAmount = 0.0;

  // Flag to track if we're in edit mode
  bool _isEditMode = false;
  PurchaseModel? _editPurchase;

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

  @override
  void initState() {
    super.initState();
    // Load data and generate invoice after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check if we're in edit mode
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null && args.containsKey('editPurchase')) {
        _isEditMode = true;
        _editPurchase = args['editPurchase'] as PurchaseModel;

        _loadInitialDataThenEdit();
      } else {
        _generateInvoiceNumber();
        _loadInitialData();
      }
    });
  }

  // Load initial data first, then load edit data
  void _loadInitialDataThenEdit() async {
    await _loadInitialData();
    if (_editPurchase != null) {
      // Wait a bit to ensure the UI is ready
      await Future.delayed(const Duration(milliseconds: 100));
      await _loadEditPurchaseData(_editPurchase!);
    }
  }

  // Load data from the purchase being edited
  Future<void> _loadEditPurchaseData(PurchaseModel purchase) async {
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );

    // Check if the vendor exists in the loaded vendors
    final vendorExists = purchaseProvider.vendors.any(
      (v) => v.id == purchase.vendorId,
    );

    if (!vendorExists) {
      await purchaseProvider.loadVendors();
    }

    // Set basic purchase data and update UI
    setState(() {
      _invoiceController.text = purchase.invoiceNo;
      _discountController.text = (purchase.discount ?? 0.0) == 0.0
          ? ''
          : (purchase.discount ?? 0.0).toString();
      _taxController.text = (purchase.tax ?? 0.0) == 0.0
          ? ''
          : (purchase.tax ?? 0.0).toString();
      _selectedVendorId = purchase.vendorId;
      _paymentMethod = purchase.paymentMethod;
      _isCredit = purchase.isCredit;
    });

    // Load purchase items
    try {
      final items = await purchaseProvider.getPurchaseItems(purchase.id);
      setState(() {
        _purchaseItems = items;
        _calculateTotals();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load purchase items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _generateInvoiceNumber() async {
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );
    try {
      // Generate base invoice number
      String invoiceNumber = await purchaseProvider.generateInvoiceNumber();

      // Check if it's unique, if not, add a suffix until we find a unique one
      bool isUnique = await purchaseProvider.isInvoiceNumberUnique(
        invoiceNumber,
      );
      int suffix = 1;

      while (!isUnique && suffix < 100) {
        // Limit to 100 attempts to avoid infinite loop
        if (invoiceNumber.contains('-')) {
          // Extract the base part (e.g., "PUR-0001")
          final basePart = invoiceNumber.split('-')[0];
          final numberPart = invoiceNumber.split('-')[1];
          invoiceNumber = '$basePart-$numberPart-$suffix';
        } else {
          invoiceNumber = '$invoiceNumber-$suffix';
        }

        isUnique = await purchaseProvider.isInvoiceNumberUnique(invoiceNumber);
        suffix++;
      }

      _invoiceController.text = invoiceNumber;
    } catch (e) {
      // Fallback to timestamp-based if generation fails
      final now = DateTime.now();
      final timestampInvoice =
          'PUR-${now.millisecondsSinceEpoch.toString().substring(8)}';

      // Still check if this fallback is unique
      try {
        bool isUnique = await purchaseProvider.isInvoiceNumberUnique(
          timestampInvoice,
        );
        if (isUnique) {
          _invoiceController.text = timestampInvoice;
        } else {
          _invoiceController.text =
              '$timestampInvoice-${now.second}${now.millisecond}';
        }
      } catch (_) {
        // If even this fails, just use the timestamp
        _invoiceController.text = timestampInvoice;
      }
    }
  }

  Future<void> _loadInitialData() async {
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );
    try {
      await purchaseProvider.loadInitialData();
      if (purchaseProvider.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${purchaseProvider.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _calculateTotals() {
    _subtotal = _purchaseItems.fold(0.0, (sum, item) => sum + item.totalPrice);
    _discount = double.tryParse(_discountController.text) ?? 0.0;
    _tax = double.tryParse(_taxController.text) ?? 0.0;
    _totalAmount = _subtotal - _discount + _tax;
    setState(() {});
  }

  // Validate invoice number uniqueness
  void _validateInvoiceNumber(String invoiceNumber) async {
    if (invoiceNumber.isEmpty) return;

    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );

    try {
      final isUnique = await purchaseProvider.isInvoiceNumberUnique(
        invoiceNumber,
        excludePurchaseId: _isEditMode ? _editPurchase?.id : null,
      );

      if (!isUnique && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice number "$invoiceNumber" already exists!'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Generate New',
              textColor: Colors.white,
              onPressed: _generateInvoiceNumber,
            ),
          ),
        );
      }
    } catch (e) {
      // Silently handle validation errors to avoid disrupting user experience
      debugPrint('Invoice validation error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConnectivityWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditMode ? 'Edit Purchase' : 'Add Purchase'),
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          actions: [
            ConnectivityAwareIconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _showBarcodeScanner,
              tooltip: 'Scan Barcode',
            ),
            ConnectivityAwareIconButton(
              icon: const Icon(Icons.save_as_outlined),
              onPressed: _saveDraft,
              tooltip: 'Save as Draft',
            ),
          ],
        ),
        body: Consumer<PurchaseProvider>(
          builder: (context, purchaseProvider, child) {
            if (purchaseProvider.isLoading &&
                purchaseProvider.products.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInvoiceSection(),
                          const SizedBox(height: 16),
                          _buildVendorSection(purchaseProvider.vendors),
                          const SizedBox(height: 16),
                          _buildPaymentMethodSection(),
                          const SizedBox(height: 16),
                          _buildItemsSection(purchaseProvider.products),
                          const SizedBox(height: 16),
                          _buildTotalsSection(),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomActions(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInvoiceSection() {
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
                  'Invoice Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: _generateInvoiceNumber,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Generate New Invoice Number',
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _invoiceController,
              decoration: const InputDecoration(
                labelText: 'Invoice Number',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.receipt),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Invoice number is required';
                }
                return null;
              },
              onChanged: (value) {
                // Clear any previous validation errors when user types
                if (value.isNotEmpty) {
                  _validateInvoiceNumber(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorSection(List<UserModel> vendors) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vendor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: vendors.any((v) => v.id == _selectedVendorId)
                  ? _selectedVendorId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Select Vendor',
                border: OutlineInputBorder(),
              ),
              isExpanded: true, // Added for better width usage
              items: [
                if (vendors.isEmpty)
                  const DropdownMenuItem(
                    value: null,
                    enabled: false,
                    child: Text(
                      'No vendors available',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ...vendors.map(
                    (vendor) => DropdownMenuItem(
                      value: vendor.id,
                      child: Tooltip(
                        message:
                            '${vendor.name} - ${vendor.phoneNumber}', // Full text on hover
                        child: Text(
                          '${vendor.name} - ${vendor.phoneNumber}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
              ],
              selectedItemBuilder: (BuildContext context) {
                return vendors.map<Widget>((vendor) {
                  return Tooltip(
                    message:
                        '${vendor.name} - ${vendor.phoneNumber}', // Full text on hover for selected item
                    child: Container(
                      width: double.infinity,
                      child: Text(
                        '${vendor.name} - ${vendor.phoneNumber}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                }).toList();
              },
              onChanged: (value) {
                setState(() {
                  _selectedVendorId = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a vendor';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 400) {
                  // Stack vertically on small screens
                  return Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('Cash'),
                        value: 'cash',
                        groupValue: _paymentMethod,
                        onChanged: (value) {
                          setState(() {
                            _paymentMethod = value!;
                            _isCredit = false;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Credit'),
                        value: 'credit',
                        groupValue: _paymentMethod,
                        onChanged: (value) {
                          setState(() {
                            _paymentMethod = value!;
                            _isCredit = true;
                          });
                        },
                      ),
                    ],
                  );
                } else {
                  // Side by side on larger screens
                  return Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Cash'),
                          value: 'cash',
                          groupValue: _paymentMethod,
                          onChanged: (value) {
                            setState(() {
                              _paymentMethod = value!;
                              _isCredit = false;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Credit'),
                          value: 'credit',
                          groupValue: _paymentMethod,
                          onChanged: (value) {
                            setState(() {
                              _paymentMethod = value!;
                              _isCredit = true;
                            });
                          },
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection(List<ProductModel> products) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Purchase Items',
                    maxLines: 2,

                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 400) {
                      // Stack vertically on small screens
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _showBarcodeScanner,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Scan Barcode'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _addItem(products),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Item'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Side by side on larger screens
                      return Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _showBarcodeScanner,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Scan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _addItem(products),
                            icon: const Icon(Icons.add),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_purchaseItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                child: const Center(
                  child: Text(
                    'No items added yet\nScan barcode or add manually',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _purchaseItems.length,
                itemBuilder: (context, index) {
                  final item = _purchaseItems[index];
                  final product = products.firstWhere(
                    (p) => p.id == item.productId,
                    orElse: () => ProductModel(
                      id: item.productId,
                      name: 'Unknown Product',
                      unit: 'pcs',
                      purchasePrice: item.unitPrice,
                      salePrice: 0,
                      categoryId: '',
                      currentStock: 0,
                      minimumStockLevel: 0,
                      createdAt: DateTime.now(),
                      isActive: true,
                      vendorId: '',
                    ),
                  );
                  return _buildItemCard(item, product, index);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(ItemModel item, ProductModel product, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Header Row: Quantity Badge + Product Name + Total Price
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Quantity Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade600,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Qty: ${item.quantity}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Product Name
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),

                // Total Price
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '\$${item.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content Row: Details + Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Left: Product Details
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Unit Price: ${item.unitPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.inventory,
                            size: 16,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Stock: ${product.currentStock.toStringAsFixed(2)} ${product.unit}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      if (product.barcode != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.qr_code,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Barcode: ${product.barcode}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Right: Action Buttons
                Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.edit,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                        onPressed: () => _editItem(index),
                        tooltip: 'Edit Item',
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.delete,
                          color: Colors.red.shade600,
                          size: 20,
                        ),
                        onPressed: () => _removeItem(index),
                        tooltip: 'Delete Item',
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Totals',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 400) {
                  // Stack vertically on small screens
                  return Column(
                    children: [
                      TextFormField(
                        controller: _discountController,
                        decoration: const InputDecoration(
                          labelText: 'Discount',
                          border: OutlineInputBorder(),
                          prefixText: '\$ ',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _calculateTotals(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _taxController,
                        decoration: const InputDecoration(
                          labelText: 'Tax',
                          border: OutlineInputBorder(),
                          prefixText: '\$ ',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _calculateTotals(),
                      ),
                    ],
                  );
                } else {
                  // Side by side on larger screens
                  return Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _discountController,
                          decoration: const InputDecoration(
                            labelText: 'Discount',
                            border: OutlineInputBorder(),
                            prefixText: '\$ ',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => _calculateTotals(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _taxController,
                          decoration: const InputDecoration(
                            labelText: 'Tax',
                            border: OutlineInputBorder(),
                            prefixText: '\$ ',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => _calculateTotals(),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildTotalRow('Subtotal', _subtotal),
                  _buildTotalRow('Discount', -_discount),
                  _buildTotalRow('Tax', _tax),
                  const Divider(thickness: 2),
                  _buildTotalRow('Total Amount', _totalAmount, isTotal: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.purple.shade700 : Colors.grey.shade700,
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.purple.shade700 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 400) {
            // Stack vertically on small screens
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _saveDraft,
                  icon: const Icon(Icons.save_as_outlined),
                  label: const Text('Save as Draft'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _completePurchase,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Complete Purchase'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            );
          } else {
            // Side by side on larger screens
            return Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saveDraft,
                    icon: const Icon(Icons.save_as_outlined),
                    label: const Text('Save as Draft'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _completePurchase,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Complete Purchase'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  } // Barcode scanner

  void _showBarcodeScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Scan Product Barcode',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final barcode = barcodes.first.rawValue;
                    if (barcode != null) {
                      Navigator.pop(context);
                      _addItemByBarcode(barcode);
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  // Add item by barcode
  void _addItemByBarcode(String barcode) async {
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );

    try {
      final product = await purchaseProvider.getProductByBarcode(barcode);

      if (product != null) {
        // Use the new _AddItemDialog with unit conversion support
        showDialog(
          context: context,
          builder: (context) => _AddItemDialog(
            products: [product], // Pass the found product
            onItemAdded: (item) {
              setState(() {
                // Check if product already exists in purchase items
                final existingIndex = _purchaseItems.indexWhere(
                  (existingItem) => existingItem.productId == item.productId,
                );

                if (existingIndex != -1) {
                  // Product already exists, increase quantity
                  final existingItem = _purchaseItems[existingIndex];
                  final newQuantity = existingItem.quantity + item.quantity;
                  final newTotalPrice = newQuantity * item.unitPrice;

                  _purchaseItems[existingIndex] = existingItem.copyWith(
                    quantity: newQuantity,
                    unitPrice: item.unitPrice,
                    totalPrice: newTotalPrice,
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${product.name} quantity updated to $newQuantity',
                      ),
                      backgroundColor: Colors.blue,
                    ),
                  );
                } else {
                  // New product, add to list
                  _purchaseItems.add(item);
                }
                _calculateTotals();
              });
            },
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product with barcode "$barcode" not found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error finding product: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Add item manually
  void _addItem(List<ProductModel> products) {
    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
        products: products,
        onItemAdded: (item) {
          setState(() {
            // Check if product already exists in purchase items
            final existingIndex = _purchaseItems.indexWhere(
              (existingItem) => existingItem.productId == item.productId,
            );

            if (existingIndex != -1) {
              // Product already exists, increase quantity
              final existingItem = _purchaseItems[existingIndex];
              final newQuantity = existingItem.quantity + item.quantity;
              final newTotalPrice = newQuantity * item.unitPrice;

              _purchaseItems[existingIndex] = existingItem.copyWith(
                quantity: newQuantity,
                unitPrice: item.unitPrice, // Update unit price in case it changed
                totalPrice: newTotalPrice,
              );

              // Show feedback to user
              final product = products.firstWhere(
                (p) => p.id == item.productId,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${product.name} quantity updated to $newQuantity',
                  ),
                  backgroundColor: Colors.blue,
                ),
              );
            } else {
              // New product, add to list
              _purchaseItems.add(item);
            }
            _calculateTotals();
          });
        },
      ),
    );
  }



  // Edit item
  void _editItem(int index) {
    final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
        products: purchaseProvider.products,
        existingItem: _purchaseItems[index],
        onItemAdded: (item) {
          setState(() {
            _purchaseItems[index] = item;
            _calculateTotals();
          });
        },
      ),
    );
  }

  // Remove item
  void _removeItem(int index) {
    setState(() {
      _purchaseItems.removeAt(index);
      _calculateTotals();
    });
  }

  // Save as draft
  void _saveDraft() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_purchaseItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate invoice number uniqueness
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );

    final isUnique = await purchaseProvider.isInvoiceNumberUnique(
      _invoiceController.text,
      excludePurchaseId: _isEditMode ? _editPurchase?.id : null,
    );

    if (!isUnique && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invoice number "${_invoiceController.text}" already exists!',
          ),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Generate New',
            textColor: Colors.white,
            onPressed: _generateInvoiceNumber,
          ),
        ),
      );
      return;
    }

    _showLoadingDialog('Saving draft purchase...');

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final purchase = PurchaseModel(
      id: _isEditMode
          ? _editPurchase!.id
          : DateTime.now().millisecondsSinceEpoch.toString(),
      totalAmount: _totalAmount,
      isReturn: false,
      isCredit: _isCredit,
      invoiceNo: _invoiceController.text,
      createdBy: authProvider.user?.uid ?? '',
      paymentMethod: _paymentMethod,
      vendorId: _selectedVendorId!,
      createdAt: _isEditMode ? _editPurchase!.createdAt : DateTime.now(),
      tax: _tax == 0.0 ? null : _tax,
      discount: _discount == 0.0 ? null : _discount,
      subtotals: _subtotal,
      status: 'drafted',
    );

    final success = await purchaseProvider.createDraftPurchase(
      purchase,
      _purchaseItems,
    );

    _hideLoadingDialog();

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase ${purchase.invoiceNo} saved as draft!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save draft: ${purchaseProvider.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Complete purchase
  void _completePurchase() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_purchaseItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate invoice number uniqueness
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );

    final isUnique = await purchaseProvider.isInvoiceNumberUnique(
      _invoiceController.text,
      excludePurchaseId: _isEditMode ? _editPurchase?.id : null,
    );

    if (!isUnique && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invoice number "${_invoiceController.text}" already exists!',
          ),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Generate New',
            textColor: Colors.white,
            onPressed: _generateInvoiceNumber,
          ),
        ),
      );
      return;
    }

    _showLoadingDialog('Processing purchase...');

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      // First create as draft
      final purchase = PurchaseModel(
        id: _isEditMode
            ? _editPurchase!.id
            : DateTime.now().millisecondsSinceEpoch.toString(),
        totalAmount: _totalAmount,
        isReturn: false,
        isCredit: _isCredit,
        invoiceNo: _invoiceController.text,
        createdBy: authProvider.user?.uid ?? '',
        paymentMethod: _paymentMethod,
        vendorId: _selectedVendorId!,
        createdAt: _isEditMode ? _editPurchase!.createdAt : DateTime.now(),
        tax: _tax == 0.0 ? null : _tax,
        discount: _discount == 0.0 ? null : _discount,
        subtotals: _subtotal,
        status: 'drafted',
      );

      // Create draft first
      bool draftSuccess = await purchaseProvider.createDraftPurchase(
        purchase,
        _purchaseItems,
      );

      if (!draftSuccess) {
        _hideLoadingDialog();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to create purchase: ${purchaseProvider.error}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Then complete it
      bool completeSuccess = await purchaseProvider.completePurchase(
        purchase.id,
      );

      _hideLoadingDialog();

      if (completeSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Purchase ${purchase.invoiceNo} completed successfully!',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to complete purchase: ${purchaseProvider.error}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      _hideLoadingDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing purchase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    super.dispose();
  }
}

// Product selection dialog
class _ProductSelectionDialog extends StatefulWidget {
  final List<ProductModel> products;
  final Function(ProductModel) onProductSelected;

  const _ProductSelectionDialog({
    required this.products,
    required this.onProductSelected,
  });

  @override
  State<_ProductSelectionDialog> createState() =>
      _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends State<_ProductSelectionDialog> {
  final _searchController = TextEditingController();
  List<ProductModel> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _filteredProducts = widget.products;
    _searchController.addListener(_filterProducts);
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = widget.products
          .where(
            (product) =>
                product.name.toLowerCase().contains(query) ||
                (product.barcode?.toLowerCase().contains(query) ?? false),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Product'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search products...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = _filteredProducts[index];
                  return ListTile(
                    title: Text(product.name),
                    subtitle: Text(
                      'Stock: ${product.currentStock} ${product.unit} | Price: \$${product.purchasePrice}',
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onProductSelected(product);
                    },
                  );
                },
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
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Add Item Dialog with Unit Conversion Support
class _AddItemDialog extends StatefulWidget {
  final List<ProductModel> products;
  final ItemModel? existingItem;
  final Function(ItemModel) onItemAdded;

  const _AddItemDialog({
    required this.products,
    required this.onItemAdded,
    this.existingItem,
  });

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();

  String? _selectedProductId;
  ProductModel? _selectedProduct;
  String? _selectedUnit;
  List<String> _availableUnits = [];
  double _totalPrice = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      _selectedProductId = widget.existingItem!.productId;
      _selectedProduct = widget.products.firstWhere(
        (p) => p.id == widget.existingItem!.productId,
        orElse: () => widget.products.first,
      );
      _selectedUnit = widget.existingItem!.unit;
      _availableUnits = UnitConverter.getSupportedUnits(_selectedProduct!.unit);
      _quantityController.text = widget.existingItem!.quantity.toString();
      _unitPriceController.text = widget.existingItem!.unitPrice.toString();
      _calculateTotal();
    }
  }

  void _calculateTotal() {
    final quantity = double.tryParse(_quantityController.text) ?? 0.0;
    final unitPrice = double.tryParse(_unitPriceController.text) ?? 0.0;
    setState(() {
      _totalPrice = quantity * unitPrice;
    });
  }

  // Convert unit price when unit changes
  double _convertUnitPrice(double currentPrice, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return currentPrice;
    
    // Convert the price based on unit conversion
    // Example: If product is $10/kg and user selects grams:
    // - 1 kg = 1000g, so price per gram = $10/1000 = $0.01/g
    // - If user selects kg from grams: price per kg = $0.01 * 1000 = $10/kg
    
    final conversionFactor = UnitConverter.convertUnit(1.0, fromUnit, toUnit);
    if (conversionFactor != 1.0) {
      // Price per unit should be inversely proportional to the unit size
      // If 1 kg = 1000g, then price per gram = price per kg / 1000
      return currentPrice / conversionFactor;
    }
    
    return currentPrice;
  }

  void _onProductSelected(String? productId) {
    if (productId != null) {
      final product = widget.products.firstWhere((p) => p.id == productId);
      setState(() {
        _selectedProductId = productId;
        _selectedProduct = product;
        _availableUnits = UnitConverter.getSupportedUnits(product.unit);
        _selectedUnit = product.unit; // Default to product's base unit
        _unitPriceController.text = product.purchasePrice.toString(); // Use purchase price for purchases
        _calculateTotal();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingItem != null ? 'Edit Item' : 'Add Item'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedProductId,
                decoration: const InputDecoration(
                  labelText: 'Product',
                  border: OutlineInputBorder(),
                ),
                items: widget.products
                    .map(
                      (product) => DropdownMenuItem(
                        value: product.id,
                        child: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _onProductSelected,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a product';
                  }
                  return null;
                },
              ),
              if (_selectedProduct != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Product Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Available Stock: ${_selectedProduct!.currentStock.toStringAsFixed(2)} ${_selectedProduct!.unit}',
                      ),
                      Text('Purchase Price: \$${_selectedProduct!.purchasePrice}'),
                      if (_selectedProduct!.barcode != null)
                        Text('Barcode: ${_selectedProduct!.barcode}'),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _calculateTotal(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Quantity is required';
                  }
                  final quantity = double.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Enter a valid quantity';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_availableUnits.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  value: _selectedUnit,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.straighten),
                  ),
                  isExpanded: true,
                  menuMaxHeight: 200,
                  items: _availableUnits.map((unit) {
                    return DropdownMenuItem<String>(
                      value: unit,
                      child: Text(unit, style: const TextStyle(fontSize: 16)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null && _selectedProduct != null) {
                      setState(() {
                        final oldUnit = _selectedUnit ?? _selectedProduct!.unit;
                        _selectedUnit = value;
                        
                        // Convert unit price when unit changes
                        if (oldUnit != value) {
                          final currentPrice = double.tryParse(_unitPriceController.text) ?? 0.0;
                          final convertedPrice = _convertUnitPrice(currentPrice, oldUnit, value);
                          _unitPriceController.text = convertedPrice.toStringAsFixed(4);
                        }
                        
                        _calculateTotal();
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a unit';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _unitPriceController,
                decoration: const InputDecoration(
                  labelText: 'Unit Price',
                  border: OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _calculateTotal(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Unit price is required';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Enter a valid price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '\$${_totalPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _addItem,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
          ),
          child: Text(widget.existingItem != null ? 'Update' : 'Add'),
        ),
      ],
    );
  }

  void _addItem() {
    if (!_formKey.currentState!.validate()) return;

    final item = ItemModel(
      referenceId: '', // Will be set when purchase is created
      productId: _selectedProductId!,
      quantity: double.parse(_quantityController.text),
      unitPrice: double.parse(_unitPriceController.text),
      totalPrice: _totalPrice,
      unit: _selectedUnit ?? _selectedProduct!.unit,
    );

    widget.onItemAdded(item);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }
}