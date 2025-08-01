import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/user_provider.dart';

class ViewProductScreen extends StatefulWidget {
  final ProductModel product;

  const ViewProductScreen({super.key, required this.product});

  @override
  State<ViewProductScreen> createState() => _ViewProductScreenState();
}

class _ViewProductScreenState extends State<ViewProductScreen> {
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentUser();
    });
  }

  void _loadCurrentUser() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (authProvider.user != null) {
      final user = await userProvider.getUserById(authProvider.user!.uid);
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Header Card
            _buildProductHeader(),
            const SizedBox(height: 20),

            // Basic Information Section
            _buildSection(
              title: 'Basic Information',
              icon: Icons.info_outline,
              color: Colors.blue,
              children: [
                _buildDetailRow(
                  icon: Icons.label,
                  label: 'Product Name',
                  value: widget.product.name,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  icon: Icons.straighten,
                  label: 'Unit',
                  value: widget.product.unit,
                  color: Colors.purple,
                ),
                if (widget.product.brand != null) ...[
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.branding_watermark,
                    label: 'Brand',
                    value: widget.product.brand!,
                    color: Colors.indigo,
                  ),
                ],
                if (widget.product.barcode != null) ...[
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.qr_code,
                    label: 'Barcode',
                    value: widget.product.barcode!,
                    color: Colors.deepOrange,
                  ),
                ],
                const SizedBox(height: 16),
                Consumer<CategoryProvider>(
                  builder: (context, categoryProvider, child) {
                    final category = categoryProvider.categories
                        .where((c) => c.id == widget.product.categoryId)
                        .firstOrNull;

                    return _buildDetailRow(
                      icon: Icons.category,
                      label: 'Category',
                      value: category?.name ?? 'Unknown Category',
                      color: Colors.orange,
                    );
                  },
                ),
              ],
            ),

            // Pricing Information Section (Admin Only)
            if (_currentUser?.role == 'admin') ...[
              const SizedBox(height: 20),
              _buildSection(
                title: 'Pricing Information',
                icon: Icons.attach_money,
                color: Colors.green,
                children: [
                  _buildDetailRow(
                    icon: Icons.attach_money,
                    label: 'Purchase Price',
                    value:
                        '\$${widget.product.purchasePrice.toStringAsFixed(2)}',
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.sell,
                    label: 'Sale Price',
                    value: '\$${widget.product.salePrice.toStringAsFixed(2)}',
                    color: Colors.teal,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.trending_up,
                    label: 'Profit Margin',
                    value:
                        '\$${(widget.product.salePrice - widget.product.purchasePrice).toStringAsFixed(2)}',
                    color: Colors.amber,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Stock Information Section
            _buildSection(
              title: 'Stock Information',
              icon: Icons.inventory_2,
              color: Colors.blue,
              children: [
                _buildDetailRow(
                  icon: Icons.inventory_2,
                  label: 'Current Stock',
                  value:
                      '${widget.product.currentStock.toStringAsFixed(2)} ${widget.product.unit}',
                  color:
                      widget.product.currentStock <=
                          widget.product.minimumStockLevel
                      ? Colors.red
                      : Colors.blue,
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  icon: Icons.warning,
                  label: 'Minimum Stock Level',
                  value:
                      '${widget.product.minimumStockLevel.toStringAsFixed(2)} ${widget.product.unit}',
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  icon: widget.product.currentStock == 0
                      ? Icons.error
                      : widget.product.currentStock <=
                            widget.product.minimumStockLevel
                      ? Icons.warning
                      : Icons.check_circle,
                  label: 'Stock Status',
                  value: widget.product.currentStock == 0
                      ? 'Out of Stock'
                      : widget.product.currentStock <=
                            widget.product.minimumStockLevel
                      ? 'Low Stock'
                      : 'In Stock',
                  color: widget.product.currentStock == 0
                      ? Colors.red
                      : widget.product.currentStock <=
                            widget.product.minimumStockLevel
                      ? Colors.orange
                      : Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Additional Information Section
            _buildSection(
              title: 'Additional Information',
              icon: Icons.more_horiz,
              color: Colors.purple,
              children: [
                _buildDetailRow(
                  icon: widget.product.isActive
                      ? Icons.check_circle
                      : Icons.cancel,
                  label: 'Status',
                  value: widget.product.isActive ? 'Active' : 'Inactive',
                  color: widget.product.isActive ? Colors.green : Colors.red,
                ),
                const SizedBox(height: 16),
                Consumer<UserProvider>(
                  builder: (context, userProvider, child) {
                    final vendor = userProvider.users
                        .where((u) => u.id == widget.product.vendorId)
                        .firstOrNull;

                    final vendorDisplayName = vendor != null
                        ? '${vendor.name}${vendor.company != null ? ' (${vendor.company})' : ''}'
                        : 'Unknown Vendor';

                    return _buildDetailRow(
                      icon: Icons.business,
                      label: 'Vendor',
                      value: vendorDisplayName,
                      color: Colors.deepPurple,
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  icon: Icons.calendar_today,
                  label: 'Created At',
                  value: _formatDateTime(widget.product.createdAt),
                  color: Colors.indigo,
                ),
                if (widget.product.updatedAt != null) ...[
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.update,
                    label: 'Last Updated',
                    value: _formatDateTime(widget.product.updatedAt!),
                    color: Colors.teal,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProductHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.product.isActive
              ? [Colors.blue[400]!, Colors.blue[600]!]
              : [Colors.grey[400]!, Colors.grey[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.inventory, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.product.currentStock.toStringAsFixed(2)} ${widget.product.unit} available',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Only show price for admin users
              if (_currentUser?.role == 'admin')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '\$${widget.product.salePrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (_currentUser?.role == 'admin') const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.product.isActive
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.product.isActive ? 'Active' : 'Inactive',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
