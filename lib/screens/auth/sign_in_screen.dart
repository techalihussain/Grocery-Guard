import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/connectivity_service.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/connectivity_wrapper.dart';
import '../../widgets/custom_logo.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _obscurePassword = true;

  void _submit() async {
    // Check connectivity first
    if (!ConnectivityService().isConnected) {
      ConnectivityService.showNoInternetDialog(context, onRetry: _submit);
      return;
    }

    final provider = Provider.of<AuthProvider>(context, listen: false);

    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter email and password"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Clear any previous errors before attempting sign in
    provider.clear();

    final role = await provider.signin(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    if (!mounted) return;

    if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!), backgroundColor: Colors.red),
      );
      return;
    }

    if (role != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Signed in Successfully"),
          backgroundColor: Colors.green,
        ),
      );
      
      // Add a small delay to ensure the success message is shown
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/$role');
      }
    } else {
      // If no role returned but no error, show generic message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sign in failed. Please try again."),
          backgroundColor: Colors.red,
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
                  const SizedBox(height: 40),

                  // Header Section
                  Center(
                    child: Column(
                      children: [
                        // Custom Logo with Animation
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
                          'Welcome Back!',
                          style: ResponsiveUtils.getResponsiveTextStyle(
                            context,
                            baseSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to access your store dashboard',
                          style: ResponsiveUtils.getResponsiveTextStyle(
                            context,
                            baseSize: 16,
                            color: Colors.grey[600],
                          ),
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

                          const SizedBox(height: 20),

                          // Password Field
                          TextField(
                            controller: passwordController,
                            obscureText: _obscurePassword,
                            enabled: !provider.isLoading,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
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

                          const SizedBox(height: 16),

                          // Forgot Password Link
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/forgetPassword');
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xffA0609F),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Sign In Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: provider.isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFC080BF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                              ),
                              child: provider.isLoading
                                  ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text('Signing In...'),
                                      ],
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.login, size: 24),
                                        SizedBox(width: 8),
                                        Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Sign Up Section
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "Don't have an account?",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/signUp');
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.indigo[600],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            'Create Account',
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
}
