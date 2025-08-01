import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';

class RegisterUserScreen extends StatefulWidget {
  final UserModel? userToEdit;
  
  const RegisterUserScreen({super.key, this.userToEdit});

  @override
  State<RegisterUserScreen> createState() => _RegisterUserScreenState();
}

class _RegisterUserScreenState extends State<RegisterUserScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Common fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Role-specific fields
  final _companyController = TextEditingController(); // For vendor
  final _addressController = TextEditingController(); // For customer
  
  String? _selectedRole;
  bool _isLoading = false;
  bool get _isEditMode => widget.userToEdit != null;

  final List<Map<String, dynamic>> _roles = [
    {
      'value': 'vendor',
      'label': 'Vendor',
      'icon': Icons.business,
      'color': Colors.teal,
      'description': 'Business partner who supplies products'
    },
    {
      'value': 'customer',
      'label': 'Customer',
      'icon': Icons.shopping_bag,
      'color': Colors.purple,
      'description': 'End user who purchases products'
    },
    {
      'value': 'storeuser',
      'label': 'Store User',
      'icon': Icons.store,
      'color': Colors.indigo,
      'description': 'Employee who manages store operations'
    },
    {
      'value': 'salesman',
      'label': 'Salesman',
      'icon': Icons.point_of_sale,
      'color': Colors.red,
      'description': 'Employee who handles sales transactions'
    },
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _initializeEditMode();
    }
  }

  void _initializeEditMode() {
    final user = widget.userToEdit!;
    _nameController.text = user.name;
    _emailController.text = user.email;
    _phoneController.text = user.phoneNumber;
    _selectedRole = user.role;
    
    // Initialize role-specific fields
    if (user.role == 'vendor' && user.company != null) {
      _companyController.text = user.company!;
    }
    if (user.role == 'customer' && user.address != null) {
      _addressController.text = user.address!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit User' : 'Register New User',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                _isEditMode ? 'Edit User Account' : 'Create New User Account',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isEditMode 
                    ? 'Update user information and role as needed'
                    : 'Select a role and fill in the required information',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // Role Selection
              _buildRoleSelection(),
              const SizedBox(height: 24),

              // Common Fields
              if (_selectedRole != null) ...[
                _buildSectionTitle('Basic Information'),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  readOnly: _isEditMode,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Role-specific fields
                _buildRoleSpecificFields(),
                const SizedBox(height: 32),

                // Register Button
                _buildRegisterButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Select User Role'),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: _roles.length,
          itemBuilder: (context, index) {
            final role = _roles[index];
            final isSelected = _selectedRole == role['value'];
            
            return Card(
              elevation: isSelected ? 8 : 4,
              shadowColor: isSelected ? role['color'].withOpacity(0.3) : Colors.grey.withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? role['color'] : Colors.transparent,
                  width: 2,
                ),
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedRole = role['value'];
                    // Clear role-specific fields when role changes
                    _companyController.clear();
                    _addressController.clear();
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        role['color'].withOpacity(isSelected ? 0.2 : 0.1),
                        role['color'].withOpacity(isSelected ? 0.1 : 0.05),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: role['color'].withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              role['icon'],
                              size: 22,
                              color: role['color'],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: Text(
                            role['label'],
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? role['color'] : Colors.grey[800],
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Flexible(
                          child: Text(
                            role['description'],
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRoleSpecificFields() {
    if (_selectedRole == null) return const SizedBox.shrink();

    switch (_selectedRole!) {
      case 'vendor':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Vendor Information'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _companyController,
              label: 'Company Name',
              icon: Icons.business,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Company name is required for vendors';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              'Account Number',
              'Will be auto-generated (ACCNO-001)',
              Icons.account_balance,
              Colors.teal,
            ),
          ],
        );
      
      case 'customer':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Customer Information'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _addressController,
              label: 'Address',
              icon: Icons.location_on,
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Address is required for customers';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              'Account Number',
              'Will be auto-generated (ACCNO-001)',
              Icons.account_balance,
              Colors.purple,
            ),
          ],
        );
      
      case 'storeuser':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Store User Information'),
            const SizedBox(height: 16),
            _buildInfoCard(
              'Employee ID',
              'Will be auto-generated (EMP-01)',
              Icons.badge,
              Colors.indigo,
            ),
          ],
        );
      
      case 'salesman':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Salesman Information'),
            const SizedBox(height: 16),
            _buildInfoCard(
              'Employee ID',
              'Will be auto-generated (EMP-01)',
              Icons.badge,
              Colors.red,
            ),
          ],
        );
      
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: readOnly ? Colors.grey[400]! : Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: readOnly ? Colors.grey[400]! : Colors.indigo[600]!),
        ),
        filled: true,
        fillColor: readOnly ? Colors.grey[100] : Colors.white,
        suffixIcon: readOnly ? const Icon(Icons.lock, color: Colors.grey) : null,
      ),
    );
  }

  Widget _buildInfoCard(String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : (_isEditMode ? _updateUser : _registerUser),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo[600],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(_isEditMode ? 'Updating User...' : 'Registering User...'),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isEditMode ? Icons.update : Icons.person_add, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    _isEditMode ? 'Update User' : 'Register User',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _registerUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // Check if email already exists
      final emailExists = await userProvider.userExistsByEmail(_emailController.text.trim());
      if (emailExists) {
        throw Exception('Email already exists');
      }

      // Create user model with role-specific fields
      final user = UserModel(
        id: '', // Will be set by repository
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        role: _selectedRole!,
        createdAt: DateTime.now(),
        isActive: false, // Pre-registered users are inactive
        company: _selectedRole == 'vendor' ? _companyController.text.trim() : null,
        address: _selectedRole == 'customer' ? _addressController.text.trim() : null,
      );

      final success = await userProvider.createUser(user);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${user.name} has been registered successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Navigate back to user management
          Navigator.pop(context);
        }
      } else {
        throw Exception(userProvider.error ?? 'Failed to register user');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final originalUser = widget.userToEdit!;
      
      // Create updated user model with role-specific fields
      final updatedUser = originalUser.copyWith(
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        role: _selectedRole!,
        company: _selectedRole == 'vendor' ? _companyController.text.trim() : null,
        address: _selectedRole == 'customer' ? _addressController.text.trim() : null,
      );

      final success = await userProvider.updateUser(updatedUser);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${updatedUser.name} has been updated successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Navigate back to user management
          Navigator.pop(context);
        }
      } else {
        throw Exception(userProvider.error ?? 'Failed to update user');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}