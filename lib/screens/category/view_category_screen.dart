import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category_model.dart';
import '../../models/user_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/user_provider.dart';

class ViewCategoryScreen extends StatefulWidget {
  final CategoryModel category;

  const ViewCategoryScreen({super.key, required this.category});

  @override
  State<ViewCategoryScreen> createState() => _ViewCategoryScreenState();
}

class _ViewCategoryScreenState extends State<ViewCategoryScreen> {
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.category.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Header Card
            _buildCategoryHeader(),
            const SizedBox(height: 20),

            // Basic Information Section
            _buildSection(
              title: 'Basic Information',
              icon: Icons.info_outline,
              color: Colors.blue,
              children: [
                _buildDetailRow(
                  icon: Icons.label,
                  label: 'Name',
                  value: widget.category.name,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  icon: widget.category.parentCategory != null
                      ? Icons.subdirectory_arrow_right
                      : Icons.category,
                  label: 'Type',
                  value: widget.category.parentCategory != null
                      ? 'Subcategory'
                      : 'Parent Category',
                  color: widget.category.parentCategory != null
                      ? Colors.green
                      : Colors.orange,
                ),
                // Parent Category (if subcategory)
                if (widget.category.parentCategory != null) ...[
                  const SizedBox(height: 16),
                  Consumer<CategoryProvider>(
                    builder: (context, categoryProvider, child) {
                      final parentCategory = categoryProvider.categories
                          .where((c) => c.id == widget.category.parentCategory)
                          .firstOrNull;

                      return _buildDetailRow(
                        icon: Icons.account_tree,
                        label: 'Parent Category',
                        value: parentCategory?.name ?? 'Unknown Parent',
                        color: Colors.purple,
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                _buildDetailRow(
                  icon: widget.category.isActive
                      ? Icons.check_circle
                      : Icons.cancel,
                  label: 'Status',
                  value: widget.category.isActive ? 'Active' : 'Inactive',
                  color: widget.category.isActive ? Colors.green : Colors.red,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Statistics Section
            _buildSection(
              title: 'Statistics',
              icon: Icons.analytics,
              color: Colors.amber,
              children: [
                FutureBuilder<Map<String, int>>(
                  future: _getDynamicCounts(widget.category),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final counts =
                        snapshot.data ?? {'subcategories': 0, 'products': 0};
                    final subcategoryCount = counts['subcategories'] ?? 0;
                    final productCount = counts['products'] ?? 0;

                    return Column(
                      children: [
                        // Subcategories count (for parent categories)
                        if (widget.category.parentCategory == null) ...[
                          _buildDetailRow(
                            icon: Icons.account_tree,
                            label: 'Subcategories',
                            value:
                                '$subcategoryCount ${subcategoryCount == 1 ? 'subcategory' : 'subcategories'}',
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Products count
                        _buildDetailRow(
                          icon: Icons.inventory,
                          label: 'Products',
                          value:
                              '$productCount ${productCount == 1 ? 'product' : 'products'}',
                          color: Colors.amber,
                        ),
                      ],
                    );
                  },
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
                  icon: Icons.calendar_today,
                  label: 'Created At',
                  value: _formatDateTime(widget.category.createdAt),
                  color: Colors.indigo,
                ),
                // Last Updated (if available)
                if (widget.category.updatedAt != null) ...[
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.update,
                    label: 'Last Updated',
                    value: _formatDateTime(widget.category.updatedAt!),
                    color: Colors.teal,
                  ),
                ],
                // Created By (if available)
                if (widget.category.createdBy != null) ...[
                  const SizedBox(height: 16),
                  FutureBuilder<UserModel?>(
                    future: Provider.of<UserProvider>(
                      context,
                      listen: false,
                    ).getUserByIdSilent(widget.category.createdBy!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildDetailRow(
                          icon: Icons.person_add,
                          label: 'Created By',
                          value: 'Loading...',
                          color: Colors.blue,
                        );
                      }

                      final user = snapshot.data;
                      return _buildDetailRow(
                        icon: Icons.person_add,
                        label: 'Created By',
                        value: user?.name ?? 'Unknown User',
                        color: Colors.blue,
                      );
                    },
                  ),
                ],
                // Last Modified By (if available)
                if (widget.category.lastModifiedBy != null) ...[
                  const SizedBox(height: 16),
                  FutureBuilder<UserModel?>(
                    future: Provider.of<UserProvider>(
                      context,
                      listen: false,
                    ).getUserByIdSilent(widget.category.lastModifiedBy!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildDetailRow(
                          icon: Icons.person,
                          label: 'Last Modified By',
                          value: 'Loading...',
                          color: Colors.deepPurple,
                        );
                      }

                      final user = snapshot.data;
                      return _buildDetailRow(
                        icon: Icons.person,
                        label: 'Last Modified By',
                        value: user?.name ?? 'Unknown User',
                        color: Colors.deepPurple,
                      );
                    },
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

  Widget _buildCategoryHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.category.isActive
              ? widget.category.parentCategory != null
                    ? [Colors.green[400]!, Colors.green[600]!]
                    : [Colors.orange[400]!, Colors.orange[600]!]
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
                child: Icon(
                  widget.category.parentCategory != null
                      ? Icons.subdirectory_arrow_right
                      : Icons.category,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.category.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.category.parentCategory != null
                          ? 'Subcategory'
                          : 'Parent Category',
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.category.isActive
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.category.isActive ? 'Active' : 'Inactive',
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
