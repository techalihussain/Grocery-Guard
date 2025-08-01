import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';

class AccountStatusChecker extends StatefulWidget {
  final Widget child;
  final String userRole;

  const AccountStatusChecker({
    super.key,
    required this.child,
    required this.userRole,
  });

  @override
  State<AccountStatusChecker> createState() => _AccountStatusCheckerState();
}

class _AccountStatusCheckerState extends State<AccountStatusChecker> {
  UserModel? currentUser;
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    // Defer the user status check until after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserStatus();
    });
  }

  Future<void> _checkUserStatus() async {
    if (!mounted) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Check if user is authenticated
      if (authProvider.user == null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/signIn');
        }
        return;
      }

      // Get current user data directly from Firestore without using provider
      UserModel? user = await _getUserDirectly(
        authProvider.user!.uid,
        authProvider.user!.email,
      );

      if (mounted) {
        setState(() {
          currentUser = user;
          isLoading = false;
          hasError = user == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
        });
      }
    }
  }

  // Direct Firestore call to avoid provider state management issues
  Future<UserModel?> _getUserDirectly(String uid, String? email) async {
    try {
      // Try to get user by UID first
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        return UserModel.fromJson(docSnapshot.data()!);
      }

      // If not found by UID and email is available, try by email
      if (email != null) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          return UserModel.fromJson(querySnapshot.docs.first.data());
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Get admin phone number for contact functionality
  Future<String?> _getAdminPhoneNumber() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final adminData = querySnapshot.docs.first.data();
        return adminData['phoneNumber'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Launch phone call to admin
  Future<void> _contactAdmin() async {
    try {
      final adminPhone = await _getAdminPhoneNumber();
      if (adminPhone != null) {
        // Clean the phone number (remove any spaces, dashes, etc.)
        final cleanPhone = adminPhone.replaceAll(RegExp(r'[^\d+]'), '');
        final Uri phoneUri = Uri.parse('tel:$cleanPhone');

        // Try to launch the phone app with the admin's number
        final bool canLaunch = await canLaunchUrl(phoneUri);
        if (canLaunch) {
          await launchUrl(phoneUri, mode: LaunchMode.externalApplication);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Opening phone app with admin number: $adminPhone',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          // If can't launch, show the phone number for manual dialing
          if (mounted) {
            _showPhoneNumberDialog(adminPhone);
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Admin contact information not available'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error contacting administrator: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show phone number dialog if direct calling fails
  void _showPhoneNumberDialog(String phoneNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.phone, color: Colors.blue),
            SizedBox(width: 8),

            Expanded(child: Text('Contact Administrator', maxLines: 2)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please call the administrator at:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      phoneNumber,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Copy to clipboard functionality can be added here
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Phone number copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Copy phone number',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tap the phone number above or manually dial it to contact the administrator.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Try to launch phone app again
              final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
              final Uri phoneUri = Uri.parse('tel:$cleanPhone');
              try {
                await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please dial the number manually'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Call Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking user status
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Show error screen if user data couldn't be loaded
    if (hasError || currentUser == null) {
      return _buildErrorScreen(context);
    }

    // If user is deactivated, show blocked screen
    if (!currentUser!.isActive) {
      return _buildDeactivatedScreen(context);
    }

    // If user is active, show the dashboard
    return widget.child;
  }

  Widget _buildErrorScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.orange[600],
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Unable to Load Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Message
              Text(
                'We couldn\'t load your account information. Please try signing in again.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Retry Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final authProvider = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    await authProvider.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/signIn');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Sign In Again',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeactivatedScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Deactivated Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.block, size: 80, color: Colors.red[600]),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Account Deactivated',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Message
              Text(
                'Your account has been deactivated by the administrator. You no longer have access to the system.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'Please contact your administrator for more information.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Contact Info Card
              InkWell(
                onTap: _contactAdmin,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.phone, size: 32, color: Colors.blue[600]),
                      const SizedBox(height: 12),
                      Text(
                        'Need Help?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Contact Administrator',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to call',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final authProvider = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    await authProvider.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/signIn');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
