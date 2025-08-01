import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/account_status_checker.dart';
import '../../widgets/connectivity_wrapper.dart';
import '../../widgets/global_card.dart';
import '../../widgets/global_dashboard_appbar.dart';
import '../../widgets/profile_dialog.dart';
import 'customer_purchases_screen.dart';
import 'due_payments_screen.dart';
import 'payment_history_screen.dart';
import 'purchase_ledger_screen.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  UserModel? currentUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentUser();
    });
  }

  Future<void> _loadCurrentUser() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (authProvider.user != null) {
      try {
        var user = await userProvider.getUserById(authProvider.user!.uid);
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
    }
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
      _loadCurrentUser().then((_) {
        if (!mounted) return;

        if (currentUser != null) {
          _showProfile();
        } else {
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
          final errorMessage =
              userProvider.error ?? 'Unable to load user profile';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
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
        themeColor: Colors.purple,
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
      userRole: 'customer',
      child: ConnectivityWrapper(
        child: PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: GlobalDashboardAppBar(
              title: 'Customer Dashboard',
              backgroundColor: Colors.purple[600]!,
              themeColor: Colors.purple,
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
                    'Welcome back, ${currentUser?.name ?? 'Customer'}!',
                    style: ResponsiveUtils.getResponsiveTextStyle(
                      context,
                      baseSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your purchases and payments',
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
                              title: 'View Purchases History',
                              icon: Icons.history,
                              color: Colors.blue,
                              isResponsive: false,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const CustomerPurchasesScreen(),
                                  ),
                                );
                              },
                            ),
                            GlobalDashboardCard(
                              title: 'Due Payments',
                              icon: Icons.payment,
                              color: Colors.red,
                              isResponsive: false,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const DuePaymentsScreen(),
                                  ),
                                );
                              },
                            ),
                            GlobalDashboardCard(
                              title: 'View Purchase Ledger',
                              icon: Icons.receipt_long,
                              color: Colors.orange,
                              isResponsive: false,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const PurchaseLedgerScreen(),
                                  ),
                                );
                              },
                            ),
                            GlobalDashboardCard(
                              title: 'Payment History',
                              icon: Icons.account_balance_wallet,
                              color: Colors.green,
                              isResponsive: false,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const PaymentHistoryScreen(),
                                  ),
                                );
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
