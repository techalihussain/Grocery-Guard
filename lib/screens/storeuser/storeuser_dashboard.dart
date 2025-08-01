import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:untitled/providers/user_provider.dart';
import 'package:untitled/screens/category/category_screen.dart';
import 'package:untitled/utils/responsive_utils.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/account_status_checker.dart';
import '../../widgets/connectivity_wrapper.dart';
import '../../widgets/global_card.dart';
import '../../widgets/global_dashboard_appbar.dart';
import '../../widgets/profile_dialog.dart';
import '../product/product_screen.dart';
import '../sale/sales_screen.dart';

class StoreuserDashboard extends StatefulWidget {
  const StoreuserDashboard({super.key});

  @override
  State<StoreuserDashboard> createState() => _StoreuserDashboardState();
}

class _StoreuserDashboardState extends State<StoreuserDashboard> {
  UserModel? currentUser;

  @override
  void initState() {
    super.initState();
    // Defer the call until after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentUser();
    });
  }

  Future<void> _loadCurrentUser() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (authProvider.user != null) {
      try {
        // First try to get user by UID
        var user = await userProvider.getUserById(authProvider.user!.uid);

        // If user is null, try to get by email as fallback
        if (user == null && authProvider.user!.email != null) {
          user = await userProvider.getUserByEmail(authProvider.user!.email!);
        }

        if (mounted) {
          setState(() {
            currentUser = user;
          });
        }
      } catch (e) {
        e;
      }
    } else {}
  }

  void _signOut() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    await authProvider.signOut();
    userProvider.clearData();

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/signIn');
    }
  }

  void _showProfileDialog() {
    if (currentUser == null) {
      // If currentUser is null, try to load it first
      _loadCurrentUser().then((_) {
        if (currentUser != null) {
          _showProfile();
        } else {
          if (!mounted) {
            return;
          }
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
          final errorMessage =
              userProvider.error ?? 'Unable to load user profile';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      });
    } else {
      _showProfile();
    }
  }

  void _showProfile() {
    showDialog(
      context: context,
      builder: (context) => ProfileDialog(
        user: currentUser!,
        themeColor: Colors.indigo,
        onUserUpdated: (updatedUser) {
          setState(() {
            currentUser = updatedUser;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AccountStatusChecker(
      userRole: 'storeuser',
      child: ConnectivityWrapper(
        child: PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: GlobalDashboardAppBar(
              title: 'Store User Dashboard',
              backgroundColor: Colors.indigo[600]!,
              themeColor: Colors.indigo,
              currentUser: currentUser,
              onProfilePressed: _showProfileDialog,
              onLogoutPressed: _signOut,
            ),
            body: Padding(
              padding: EdgeInsets.all(context.responsivePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, ${currentUser?.name ?? 'Store User'}!',
                    style: ResponsiveUtils.getResponsiveTextStyle(
                      context,
                      baseSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your store operations',
                    style: ResponsiveUtils.getResponsiveTextStyle(
                      context,
                      baseSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Responsive grid based on screen width - always at least 2 columns
                        int crossAxisCount = 2;
                        if (constraints.maxWidth > 800) {
                          crossAxisCount = 3;
                        }
                        // Always keep minimum 2 columns for better card layout

                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.0,
                          children: [
                            GlobalDashboardCard(
                              title: 'Category Management',
                              icon: Icons.category,
                              color: Colors.orange,
                              isResponsive: false,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const CategoryScreen(),
                                  ),
                                );
                              },
                            ),
                            GlobalDashboardCard(
                              title: 'Product Management',
                              icon: Icons.inventory,
                              color: Colors.green,
                              isResponsive: false,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ProductScreen(),
                                  ),
                                );
                              },
                            ),
                            GlobalDashboardCard(
                              title: 'Sale Management',
                              icon: Icons.point_of_sale,
                              color: Colors.purple,
                              isResponsive: false,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SalesScreen(),
                                  ),
                                );
                              },
                            ),
                            GlobalDashboardCard(
                              title: 'Purchase Management',
                              icon: Icons.shopping_cart,
                              color: Colors.teal,
                              isResponsive: false,
                              onTap: () {
                                Navigator.pushNamed(context, '/purchase');
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
