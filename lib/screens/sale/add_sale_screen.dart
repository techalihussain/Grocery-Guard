import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../models/product_model.dart';
import '../../models/sale_model.dart';
import '../../models/sale_purchase_item_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sales_provider.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/unit_converter.dart';
import '../../widgets/connectivity_wrapper.dart';

class AddSaleScreen extends StatefulWidget {
  const AddSaleScreen({super.key});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceController = TextEditingController();
  final _discountController = TextEditingController();
  final _taxController = TextEditingController();

  List<ItemModel> _saleItems = [];
  String? _selectedCustomerId;
  String _paymentMethod = 'cash';
  bool _isCredit = false;
  double _subtotal = 0.0;
  double _discount = 0.0;
  double _tax = 0.0;
  double _totalAmount = 0.0;

  // Flag to track if we're in edit mode
  bool _isEditMode = false;
  SaleModel? _editSale;

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

      if (args != null && args.containsKey('editSale')) {
        _isEditMode = true;
        _editSale = args['editSale'] as SaleModel;

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
    if (_editSale != null) {
      // Wait a bit to ensure the UI is ready
      await Future.delayed(const Duration(milliseconds: 100));
      await _loadEditSaleData(_editSale!);
    }
  }

  // Load data from the sale being edited
  Future<void> _loadEditSaleData(SaleModel sale) async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);

    // Check if the customer exists in the loaded customers
    final customerExists = salesProvider.customers.any(
      (c) => c.id == sale.customerId,
    );

    if (!customerExists) {
      await salesProvider.loadCustomers();
    }

    // Set basic sale data and update UI
    setState(() {
      _invoiceController.text = sale.invoiceNo;
      _discountController.text = (sale.discount ?? 0.0) == 0.0
          ? ''
          : (sale.discount ?? 0.0).toString();
      _taxController.text = (sale.tax ?? 0.0) == 0.0
          ? ''
          : (sale.tax ?? 0.0).toString();
      _selectedCustomerId = sale.customerId;
      _paymentMethod = sale.paymentMethod;
      _isCredit = sale.isCredit;
    });

    // Load sale items
    try {
      final items = await salesProvider.getSaleItems(sale.id);
      setState(() {
        _saleItems = items;
        _calculateTotals();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load sale items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _generateInvoiceNumber() async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    try {
      // Generate base invoice number
      String invoiceNumber = await salesProvider.generateInvoiceNumber();

      // Check if it's unique, if not, add a suffix until we find a unique one
      bool isUnique = await salesProvider.isInvoiceNumberUnique(invoiceNumber);
      int suffix = 1;

      while (!isUnique && suffix < 100) {
        // Limit to 100 attempts to avoid infinite loop
        if (invoiceNumber.contains('-')) {
          // Extract the base part (e.g., "INV-0001")
          final basePart = invoiceNumber.split('-')[0];
          final numberPart = invoiceNumber.split('-')[1];
          invoiceNumber = '$basePart-$numberPart-$suffix';
        } else {
          invoiceNumber = '$invoiceNumber-$suffix';
        }

        isUnique = await salesProvider.isInvoiceNumberUnique(invoiceNumber);
        suffix++;
      }

      _invoiceController.text = invoiceNumber;
    } catch (e) {
      // Fallback to timestamp-based if generation fails
      final now = DateTime.now();
      final timestampInvoice =
          'INV-${now.millisecondsSinceEpoch.toString().substring(8)}';

      // Still check if this fallback is unique
      try {
        bool isUnique = await salesProvider.isInvoiceNumberUnique(
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
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    try {
      await salesProvider.loadInitialData();
      if (salesProvider.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${salesProvider.error}'),
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
    _subtotal = _saleItems.fold(0.0, (sum, item) => sum + item.totalPrice);
    _discount = double.tryParse(_discountController.text) ?? 0.0;
    _tax = double.tryParse(_taxController.text) ?? 0.0;
    _totalAmount = _subtotal - _discount + _tax;
    setState(() {});
  }

  // Validate invoice number uniqueness
  void _validateInvoiceNumber(String invoiceNumber) async {
    if (invoiceNumber.isEmpty) return;

    final salesProvider = Provider.of<SalesProvider>(context, listen: false);

    try {
      final isUnique = await salesProvider.isInvoiceNumberUnique(
        invoiceNumber,
        excludeSaleId: _isEditMode ? _editSale?.id : null,
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
          title: Text(_isEditMode ? 'Edit Sale' : 'Add Sale'),
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
        body: Consumer<SalesProvider>(
          builder: (context, salesProvider, child) {
            if (salesProvider.isLoading && salesProvider.products.isEmpty) {
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
                          _buildCustomerSection(salesProvider.customers),
                          const SizedBox(height: 16),
                          _buildPaymentMethodSection(),
                          const SizedBox(height: 16),
                          _buildItemsSection(salesProvider.products),
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

  Widget _buildCustomerSection(List<UserModel> customers) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: customers.any((c) => c.id == _selectedCustomerId)
                  ? _selectedCustomerId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Select Customer',
                border: OutlineInputBorder(),
              ),
              isExpanded: true, // Added for better width usage
              items: [
                if (customers.isEmpty)
                  const DropdownMenuItem(
                    value: null,
                    enabled: false,
                    child: Text(
                      'No customers available',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ...customers.map(
                    (customer) => DropdownMenuItem(
                      value: customer.id,
                      child: Tooltip(
                        message:
                            '${customer.name} - ${customer.phoneNumber}', // Full text on hover
                        child: Text(
                          '${customer.name} - ${customer.phoneNumber}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
              ],
              selectedItemBuilder: (BuildContext context) {
                return customers.map<Widget>((customer) {
                  return Tooltip(
                    message:
                        '${customer.name} - ${customer.phoneNumber}', // Full text on hover for selected item
                    child: Container(
                      width: double.infinity,
                      child: Text(
                        '${customer.name} - ${customer.phoneNumber}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                }).toList();
              },
              onChanged: (value) {
                setState(() {
                  _selectedCustomerId = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a customer';
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
                const Text(
                  'Sale Items',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            if (_saleItems.isEmpty)
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
                itemCount: _saleItems.length,
                itemBuilder: (context, index) {
                  final item = _saleItems[index];
                  final product = products.firstWhere(
                    (p) => p.id == item.productId,
                    orElse: () => ProductModel(
                      id: item.productId,
                      name: 'Unknown Product',
                      unit: 'pcs',
                      purchasePrice: 0,
                      salePrice: item.unitPrice,
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
              color: Colors.green.shade50,
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
                    color: Colors.green.shade600,
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
                    color: Colors.green.shade600,
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
                            'Unit Price: \$${item.unitPrice.toStringAsFixed(2)}',
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
            _buildTotalRow('Subtotal:', _subtotal),
            _buildTotalRow('Discount:', -_discount),
            _buildTotalRow('Tax:', _tax),
            const Divider(thickness: 2),
            _buildTotalRow('Total:', _totalAmount, isTotal: true),
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
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green.shade700 : null,
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
            color: Colors.grey.withValues(alpha: 0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
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
                OutlinedButton(
                  onPressed: _saveDraft,
                  child: const Text('Save Draft'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _completeSale,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Complete Sale'),
                ),
              ],
            );
          } else {
            // Side by side on larger screens
            return Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saveDraft,
                    child: const Text('Save Draft'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _completeSale,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Complete Sale'),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  // Barcode Scanner
  void _showBarcodeScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height:
            MediaQuery.of(context).size.height *
            (context.isSmallScreen ? 0.8 : 0.7),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          minHeight: 400,
        ),
        child: Column(
          children: [
            AppBar(
              title: Text(
                'Scan Barcode',
                style: ResponsiveUtils.getResponsiveTextStyle(
                  context,
                  baseSize: 18,
                ),
              ),
              automaticallyImplyLeading: false,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      Navigator.pop(context);
                      _handleBarcodeScanned(barcode.rawValue!);
                      break;
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Handle scanned barcode
  void _handleBarcodeScanned(String barcode) async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);

    // Find product by barcode
    final product = await salesProvider.getProductByBarcode(barcode);

    if (product == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product not found for barcode: $barcode'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Check if product already exists in sale items
    final existingIndex = _saleItems.indexWhere(
      (item) => item.productId == product.id,
    );

    if (existingIndex != -1) {
      // Increase quantity by 1
      final existingItem = _saleItems[existingIndex];
      final newQuantity = existingItem.quantity + 1;

      // Check stock availability
      if (newQuantity > product.currentStock) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Insufficient stock! Available: ${product.currentStock.toStringAsFixed(2)}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Update existing item
      _saleItems[existingIndex] = existingItem.copyWith(
        quantity: newQuantity,
        totalPrice: newQuantity * existingItem.unitPrice,
      );
    } else {
      // Add new item with quantity 1
      if (product.currentStock < 1 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product is out of stock!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final newItem = ItemModel(
        referenceId: '', // Will be set when sale is created
        productId: product.id,
        quantity: 1.0,
        unitPrice: product.salePrice,
        totalPrice: product.salePrice,
        unit: product.unit, // Use product's base unit for barcode scanning
      );

      _saleItems.add(newItem);
    }

    _calculateTotals();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} added to sale'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _addItem(List<ProductModel> products) {
    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
        products: products,
        onItemAdded: (item) {
          setState(() {
            // Check if product already exists in sale items
            final existingIndex = _saleItems.indexWhere(
              (existingItem) => existingItem.productId == item.productId,
            );

            if (existingIndex != -1) {
              // Product already exists, increase quantity
              final existingItem = _saleItems[existingIndex];
              final newQuantity = existingItem.quantity + item.quantity;
              final newTotalPrice = newQuantity * item.unitPrice;

              _saleItems[existingIndex] = existingItem.copyWith(
                quantity: newQuantity,
                unitPrice:
                    item.unitPrice, // Update unit price in case it changed
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
              _saleItems.add(item);
            }
            _calculateTotals();
          });
        },
      ),
    );
  }

  void _editItem(int index) {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
        products: salesProvider.products,
        existingItem: _saleItems[index],
        onItemAdded: (item) {
          setState(() {
            _saleItems[index] = item;
            _calculateTotals();
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _saleItems.removeAt(index);
      _calculateTotals();
    });
  }

  void _saveDraft() async {
    if (!_formKey.currentState!.validate() || _saleItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill all required fields and add at least one item',
          ),
        ),
      );
      return;
    }

    // Additional validation
    if (_selectedCustomerId == null || _selectedCustomerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_invoiceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an invoice number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _showLoadingDialog('Checking invoice number...');

    try {
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);

      // Check if invoice number is unique
      final invoiceNumber = _invoiceController.text;
      final String? excludeSaleId = _isEditMode && _editSale != null
          ? _editSale!.id
          : null;
      final isUnique = await salesProvider.isInvoiceNumberUnique(
        invoiceNumber,
        excludeSaleId: excludeSaleId,
      );

      if (!isUnique) {
        _hideLoadingDialog();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invoice number "$invoiceNumber" already exists!'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Generate New',
                textColor: Colors.white,
                onPressed: _generateInvoiceNumber,
              ),
            ),
          );
        }
        return;
      }

      _hideLoadingDialog();
      _showLoadingDialog('Saving draft...');

      bool success = false;

      if (_isEditMode && _editSale != null) {
        // Update existing draft sale
        // First delete the old draft
        success = await salesProvider.deleteDraftSale(_editSale!.id);
        if (!success && mounted) {
          _hideLoadingDialog();
          final errorMessage = salesProvider.error != null
              ? 'Error deleting old draft: ${salesProvider.error}'
              : 'Error deleting old draft: Unknown error occurred';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
          return;
        }

        // Then create a new one with updated data
        final sale = _createSaleModel('drafted');
        success = await salesProvider.createDraftSale(sale, _saleItems);

        _hideLoadingDialog();
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Draft updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else if (mounted) {
          final errorMessage = salesProvider.error != null
              ? 'Error updating draft: ${salesProvider.error}'
              : 'Error updating draft: Unknown error occurred';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      } else {
        // Create new draft sale
        final sale = _createSaleModel('drafted');
        success = await salesProvider.createDraftSale(sale, _saleItems);

        _hideLoadingDialog();
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Draft saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else if (mounted) {
          final errorMessage = salesProvider.error != null
              ? 'Error: ${salesProvider.error}'
              : 'Error: Failed to save draft';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      _hideLoadingDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _completeSale() async {
    if (!_formKey.currentState!.validate() || _saleItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill all required fields and add at least one item',
          ),
        ),
      );
      return;
    }

    // Additional validation
    if (_selectedCustomerId == null || _selectedCustomerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_invoiceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an invoice number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _showLoadingDialog('Checking invoice number...');

    try {
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);

      // Check if invoice number is unique
      final invoiceNumber = _invoiceController.text;
      final String? excludeSaleId = _isEditMode && _editSale != null
          ? _editSale!.id
          : null;
      final isUnique = await salesProvider.isInvoiceNumberUnique(
        invoiceNumber,
        excludeSaleId: excludeSaleId,
      );

      if (!isUnique) {
        _hideLoadingDialog();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invoice number "$invoiceNumber" already exists!'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Generate New',
                textColor: Colors.white,
                onPressed: _generateInvoiceNumber,
              ),
            ),
          );
        }
        return;
      }

      _hideLoadingDialog();
      _showLoadingDialog('Validating stock...');

      // Validate stock first
      final stockValid = await salesProvider.validateStock(_saleItems);
      if (!stockValid) {
        _hideLoadingDialog();
        if (mounted) {
          final errorMessage = salesProvider.error != null
              ? 'Stock validation failed: ${salesProvider.error}'
              : 'Stock validation failed: Insufficient stock for one or more items';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
        return;
      }

      // Update loading message
      _hideLoadingDialog();
      _showLoadingDialog('Creating sale...');

      // Create sale as draft first, then complete it
      final sale = _createSaleModel('drafted');
      final success = await salesProvider.createDraftSale(sale, _saleItems);

      if (success) {
        // Update loading message
        _hideLoadingDialog();
        _showLoadingDialog('Completing sale...');

        // Now complete the draft sale
        final completed = await salesProvider.completeSale(sale.id);
        _hideLoadingDialog();

        if (completed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sale completed successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else if (mounted) {
          final errorMessage = salesProvider.error != null
              ? 'Error completing sale: ${salesProvider.error}'
              : 'Error completing sale: Unknown error occurred';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      } else {
        _hideLoadingDialog();
        if (mounted) {
          final errorMessage = salesProvider.error != null
              ? 'Error creating sale: ${salesProvider.error}'
              : 'Error creating sale: Unknown error occurred';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      _hideLoadingDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  SaleModel _createSaleModel(String status) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid ?? 'unknown_user';

    // If in edit mode, preserve the original ID and creation date
    final String id = _isEditMode && _editSale != null
        ? _editSale!.id
        : DateTime.now().millisecondsSinceEpoch.toString();

    final DateTime createdAt = _isEditMode && _editSale != null
        ? _editSale!.createdAt
        : DateTime.now();

    // Ensure all required string fields are not null
    final String invoiceNo = _invoiceController.text.trim().isEmpty
        ? 'INV-${DateTime.now().millisecondsSinceEpoch}'
        : _invoiceController.text.trim();

    final String customerId = _selectedCustomerId ?? '';
    if (customerId.isEmpty) {
      throw Exception('Customer must be selected');
    }

    final String paymentMethod = _paymentMethod.isEmpty
        ? 'cash'
        : _paymentMethod;

    return SaleModel(
      id: id,
      totalAmount: _totalAmount,
      isReturn: false,
      isCredit: _isCredit,
      invoiceNo: invoiceNo,
      createdBy: currentUserId,
      paymentMethod: paymentMethod,
      customerId: customerId,
      createdAt: createdAt,
      tax: _tax,
      discount: _discount,
      subtotals: _subtotal,
      status: status,
    );
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    super.dispose();
  }
}

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
        _unitPriceController.text = product.salePrice.toString();
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
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Product Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Available Stock: ${_selectedProduct!.currentStock.toStringAsFixed(2)} ${_selectedProduct!.unit}',
                      ),
                      Text('Sale Price: \$${_selectedProduct!.salePrice}'),
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
                  if (_selectedProduct != null && _selectedUnit != null) {
                    // Convert quantity to base unit for stock comparison
                    final quantityInBaseUnit = UnitConverter.convertToBaseUnit(
                      quantity,
                      _selectedUnit!,
                    );
                    if (quantityInBaseUnit > _selectedProduct!.currentStock) {
                      final availableInSelectedUnit =
                          UnitConverter.convertFromBaseUnit(
                            _selectedProduct!.currentStock,
                            _selectedUnit!,
                          );
                      return 'Quantity exceeds available stock (${UnitConverter.formatQuantity(availableInSelectedUnit, _selectedUnit!)} $_selectedUnit)';
                    }
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
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
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
                        color: Colors.green.shade700,
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
            backgroundColor: Colors.green,
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
      referenceId: '', // Will be set when sale is created
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
