import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import 'register_user_screen.dart';

class UserManagement extends StatefulWidget {
  const UserManagement({super.key});

  @override
  State<UserManagement> createState() => _UserManagementState();
}

class _UserManagementState extends State<UserManagement> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.loadAllUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'User Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          if (userProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final allUsers = userProvider.users;
          final activeUsers = userProvider.activeUsers;
          final inactiveUsers = userProvider.inactiveUsers;

          // Count users by role
          final adminUsers = allUsers.where((u) => u.role == 'admin').length;
          final customerUsers = allUsers
              .where((u) => u.role == 'customer')
              .length;
          final vendorUsers = allUsers.where((u) => u.role == 'vendor').length;
          final salesmanUsers = allUsers
              .where((u) => u.role == 'salesman')
              .length;
          final storeUsers = allUsers
              .where((u) => u.role == 'storeuser')
              .length;

          return RefreshIndicator(
            onRefresh: _loadUserData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text(
                    'User Overview',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage and monitor all users in your system',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),

                  // Register User Card (Full Width)
                  _buildRegisterUserCard(),
                  const SizedBox(height: 20),

                  // User Statistics Cards
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                    children: [
                      _buildStatCard(
                        title: 'All Users',
                        count: allUsers.length,
                        icon: Icons.people,
                        color: Colors.blue,
                        onTap: () => _showUserList('All Users', allUsers),
                      ),
                      _buildStatCard(
                        title: 'Active Users',
                        count: activeUsers.length,
                        icon: Icons.person,
                        color: Colors.green,
                        onTap: () => _showUserList('Active Users', activeUsers),
                      ),
                      _buildStatCard(
                        title: 'Inactive Users',
                        count: inactiveUsers.length,
                        icon: Icons.person_off,
                        color: Colors.orange,
                        onTap: () =>
                            _showUserList('Inactive Users', inactiveUsers),
                      ),
                      _buildStatCard(
                        title: 'Customers',
                        count: customerUsers,
                        icon: Icons.shopping_bag,
                        color: Colors.purple,
                        onTap: () => _showUserList(
                          'Customers',
                          allUsers.where((u) => u.role == 'customer').toList(),
                        ),
                      ),
                      _buildStatCard(
                        title: 'Vendors',
                        count: vendorUsers,
                        icon: Icons.business,
                        color: Colors.teal,
                        onTap: () => _showUserList(
                          'Vendors',
                          allUsers.where((u) => u.role == 'vendor').toList(),
                        ),
                      ),
                      _buildStatCard(
                        title: 'Salesmen',
                        count: salesmanUsers,
                        icon: Icons.point_of_sale,
                        color: Colors.red,
                        onTap: () => _showUserList(
                          'Salesmen',
                          allUsers.where((u) => u.role == 'salesman').toList(),
                        ),
                      ),
                      _buildStatCard(
                        title: 'Store Users',
                        count: storeUsers,
                        icon: Icons.store,
                        color: Colors.indigo,
                        onTap: () => _showUserList(
                          'Store Users',
                          allUsers.where((u) => u.role == 'storeuser').toList(),
                        ),
                      ),
                      _buildStatCard(
                        title: 'Admins',
                        count: adminUsers,
                        icon: Icons.admin_panel_settings,
                        color: Colors.deepOrange,
                        onTap: () => _showUserList(
                          'Admins',
                          allUsers.where((u) => u.role == 'admin').toList(),
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

  Widget _buildRegisterUserCard() {
    return Card(
      elevation: 8,
      shadowColor: Colors.indigo.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Navigate to register user screen
          _showRegisterUserDialog();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.indigo.withValues(alpha: 0.1),
                Colors.indigo.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_add,
                  size: 32,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Register New User',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Add a new user to the system',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.indigo,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 6,
      shadowColor: color.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
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
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 24, color: color),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUserList(String title, List<UserModel> users) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${users.length} users',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: users.isEmpty
                    ? const Center(
                        child: Text(
                          'No users found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: CircleAvatar(
                                backgroundColor: user.isActive
                                    ? Colors.green
                                    : Colors.orange,
                                child: Text(
                                  user.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                user.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.email),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo[100],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          user.role.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.indigo[800],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: user.isActive ? Colors.green[100] : Colors.orange[100],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          user.isActive ? 'ACTIVE' : 'INACTIVE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: user.isActive ? Colors.green[800] : Colors.orange[800],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: user.role == 'admin' 
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'PROTECTED',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.amber[800],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (value) => _handleUserAction(value, user),
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'view',
                                          child: Row(
                                            children: [
                                              Icon(Icons.visibility, color: Colors.green, size: 20),
                                              SizedBox(width: 8),
                                              Text('View User'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, color: Colors.blue, size: 20),
                                              SizedBox(width: 8),
                                              Text('Edit User'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: user.isActive ? 'deactivate' : 'activate',
                                          child: Row(
                                            children: [
                                              Icon(
                                                user.isActive ? Icons.block : Icons.check_circle,
                                                color: user.isActive ? Colors.orange : Colors.green,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(user.isActive ? 'Deactivate' : 'Activate'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete, color: Colors.red, size: 20),
                                              SizedBox(width: 8),
                                              Text('Delete', style: TextStyle(color: Colors.red)),
                                            ],
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
        ),
      ),
    );
  }

  void _handleUserAction(String action, UserModel user) {
    switch (action) {
      case 'view':
        _viewUser(user);
        break;
      case 'edit':
        _editUser(user);
        break;
      case 'activate':
        _activateUser(user);
        break;
      case 'deactivate':
        _deactivateUser(user);
        break;
      case 'delete':
        _showDeleteConfirmation(user);
        break;
    }
  }

  void _viewUser(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: user.isActive ? Colors.green : Colors.orange,
              child: Text(
                user.name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: user.isActive ? Colors.green[100] : Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user.isActive ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        color: user.isActive ? Colors.green[800] : Colors.orange[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserInfoRow('Email', user.email, Icons.email),
              const SizedBox(height: 12),
              _buildUserInfoRow('Phone', user.phoneNumber, Icons.phone),
              const SizedBox(height: 12),
              _buildUserInfoRow('Role', user.role.toUpperCase(), Icons.work),
              const SizedBox(height: 12),
              _buildUserInfoRow(
                'Created', 
                '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
                Icons.calendar_today
              ),
              
              // Role-specific information
              if (user.role == 'vendor' && user.company != null) ...[
                const SizedBox(height: 12),
                _buildUserInfoRow('Company', user.company!, Icons.business),
              ],
              if (user.role == 'customer' && user.address != null) ...[
                const SizedBox(height: 12),
                _buildUserInfoRow('Address', user.address!, Icons.location_on),
              ],
              if ((user.role == 'salesman' || user.role == 'storeuser') && user.employeeId != null) ...[
                const SizedBox(height: 12),
                _buildUserInfoRow('Employee ID', user.employeeId!, Icons.badge),
              ],
              if ((user.role == 'customer' || user.role == 'vendor') && user.accountNo != null) ...[
                const SizedBox(height: 12),
                _buildUserInfoRow('Account No', user.accountNo!, Icons.account_balance),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (user.role != 'admin')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close view dialog
                _editUser(user); // Open edit screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('Edit User'),
            ),
        ],
      ),
    );
  }

  Widget _buildUserInfoRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.indigo[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: Colors.indigo[600], size: 16),
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
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _editUser(UserModel user) {
    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterUserScreen(userToEdit: user),
      ),
    ).then((_) {
      // Refresh data when returning from edit screen
      _loadUserData();
    });
  }

  void _showEditUserDialog(UserModel user) {
    final nameController = TextEditingController(text: user.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User Name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Email: ${user.email}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              'Role: ${user.role.toUpperCase()}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _updateUserName(user, nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _updateUserName(UserModel user, String newName) async {
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pop(context); // Close dialog
    Navigator.pop(context); // Close bottom sheet

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final updatedUser = user.copyWith(name: newName);
    
    final success = await userProvider.updateUser(updatedUser);
    
    if (success && mounted) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User name updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadUserData(); // Refresh data
    } else if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update user: ${userProvider.error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _activateUser(UserModel user) async {
    Navigator.pop(context); // Close bottom sheet
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final success = await userProvider.activateUser(user.id);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.name} has been activated!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadUserData(); // Refresh data
    } else if(mounted){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to activate user: ${userProvider.error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deactivateUser(UserModel user) async {
    Navigator.pop(context); // Close bottom sheet
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final success = await userProvider.deactivateUser(user.id);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.name} has been deactivated!'),
          backgroundColor: Colors.orange,
        ),
      );
      _loadUserData(); // Refresh data
    } else if(mounted){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to deactivate user: ${userProvider.error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this user?'),
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
                  Text(
                    'Name: ${user.name}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text('Email: ${user.email}'),
                  Text('Role: ${user.role.toUpperCase()}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone!',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
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
            onPressed: () => _deleteUser(user),
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

  void _deleteUser(UserModel user) async {
    Navigator.pop(context); // Close confirmation dialog
    Navigator.pop(context); // Close bottom sheet
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final success = await userProvider.deleteUser(user.id);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.name} has been deleted!'),
          backgroundColor: Colors.red,
        ),
      );
      _loadUserData(); // Refresh data
    } else if(mounted){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete user: ${userProvider.error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRegisterUserDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RegisterUserScreen(),
      ),
    ).then((_) {
      // Refresh data when returning from register screen
      _loadUserData();
    });
  }
}
