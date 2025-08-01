import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/global_card.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
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
        // Handle error silently
      }
    }
  }

  bool get isAdmin => currentUser?.role.toLowerCase() == 'admin';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Purchase Management',
          style: ResponsiveUtils.getResponsiveTextStyle(
            context,
            baseSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(context.responsivePadding),
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
                  title: 'Add Purchase',
                  icon: Icons.add_shopping_cart,
                  color: Colors.green,
                  onTap: () {
                    Navigator.pushNamed(context, '/add-purchase');
                  },
                ),
                GlobalDashboardCard(
                  title: 'Draft Purchases',
                  icon: Icons.drafts,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pushNamed(context, '/draft-purchases');
                  },
                ),
                GlobalDashboardCard(
                  title: 'Purchase History',
                  icon: Icons.history,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pushNamed(context, '/purchase-history');
                  },
                ),
                GlobalDashboardCard(
                  title: 'Vendor Payments',
                  icon: Icons.payment,
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pushNamed(context, '/vendor-payments');
                  },
                ),
                GlobalDashboardCard(
                  title: 'Process Return',
                  icon: Icons.keyboard_return,
                  color: Colors.red,
                  onTap: () {
                    Navigator.pushNamed(context, '/process-purchase-return');
                  },
                ),
                // Only show Purchase Reports card for admin users
                if (isAdmin)
                  GlobalDashboardCard(
                    title: 'Purchase Reports',
                    icon: Icons.analytics,
                    color: Colors.teal,
                    onTap: () {
                      Navigator.pushNamed(context, '/purchase-reports');
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
