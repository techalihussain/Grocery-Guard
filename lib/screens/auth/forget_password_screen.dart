import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/connectivity_service.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/connectivity_wrapper.dart';
import '../../widgets/custom_logo.dart';

class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  final emailController = TextEditingController();
  bool _emailSent = false;

  void _resetPassword() async {
    // Check connectivity first
    if (!ConnectivityService().isConnected) {
      ConnectivityService.showNoInternetDialog(context, onRetry: _resetPassword);
      return;
    }

    final provider = Provider.of<AuthProvider>(context, listen: false);

    if (emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter your email address"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success = await provider.resetPassword(emailController.text.trim());

    if (provider.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (success && mounted) {
      setState(() {
        _emailSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password reset email sent! Check your inbox."),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AuthProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return ConnectivityWrapper(
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? screenWidth * 0.2 : 24.0,
                vertical: 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Header Section
                  Center(
                    child: Column(
                      children: [
                        // Custom Logo
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC080BF),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const AnimatedCustomLogo(
                            size: 80,
                            imagePath: 'assets/mylogo.png',
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _emailSent ? 'Check Your Email' : 'Reset Password',
                          style: ResponsiveUtils.getResponsiveTextStyle(
                            context,
                            baseSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _emailSent
                              ? 'We\'ve sent a password reset link to your email'
                              : 'Enter your email to receive a password reset link',
                          style: ResponsiveUtils.getResponsiveTextStyle(
                            context,
                            baseSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Form Section
                  Card(
                    elevation: 8,
                    shadowColor: Colors.indigo.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          if (!_emailSent) ...[
                            // Email Field
                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              enabled: !provider.isLoading,
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.indigo[600]!,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Reset Password Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: provider.isLoading ? null : _resetPassword,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC080BF),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 4,
                                ),
                                child: provider.isLoading
                                    ? const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text('Sending...'),
                                        ],
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.email_outlined, size: 24),
                                          SizedBox(width: 8),
                                          Text(
                                            'Send Reset Link',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ] else ...[
                            // Success State
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green[200]!),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.mark_email_read,
                                    size: 64,
                                    color: Colors.green[600],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Email Sent Successfully!',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[800],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Please check your email and follow the instructions to reset your password.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.green[700],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Back to Sign In Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFC080BF)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.arrow_back, color: Color(0xFFC080BF)),
                                    SizedBox(width: 8),
                                    Text(
                                      'Back to Sign In',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFC080BF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Additional Info
                  if (!_emailSent)
                    Center(
                      child: Column(
                        children: [
                          Text(
                            "Remember your password?",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.indigo[600],
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: const Text(
                              'Back to Sign In',
                              style: TextStyle(
                                color: Color(0xffA0609F),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }
}