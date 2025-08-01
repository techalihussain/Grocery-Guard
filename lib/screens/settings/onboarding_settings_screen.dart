import 'package:flutter/material.dart';
import '../../services/onboarding_service.dart';

class OnboardingSettingsScreen extends StatefulWidget {
  const OnboardingSettingsScreen({super.key});

  @override
  State<OnboardingSettingsScreen> createState() => _OnboardingSettingsScreenState();
}

class _OnboardingSettingsScreenState extends State<OnboardingSettingsScreen> {
  bool _isOnboardingCompleted = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  void _checkOnboardingStatus() async {
    final isCompleted = await OnboardingService.isOnboardingCompleted();
    setState(() {
      _isOnboardingCompleted = isCompleted;
    });
  }

  void _resetOnboarding() async {
    await OnboardingService.resetOnboarding();
    setState(() {
      _isOnboardingCompleted = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Onboarding reset successfully! Restart the app to see onboarding.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showOnboarding() {
    Navigator.pushNamed(context, '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Onboarding Settings'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Onboarding Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          _isOnboardingCompleted 
                              ? Icons.check_circle 
                              : Icons.radio_button_unchecked,
                          color: _isOnboardingCompleted 
                              ? Colors.green 
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isOnboardingCompleted 
                              ? 'Onboarding Completed' 
                              : 'Onboarding Not Completed',
                          style: TextStyle(
                            fontSize: 16,
                            color: _isOnboardingCompleted 
                                ? Colors.green 
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showOnboarding,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('View Onboarding'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _resetOnboarding,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset Onboarding'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'About Onboarding',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'The onboarding flow introduces new users to the key features of the inventory management system:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text('• User Management', style: TextStyle(fontSize: 14)),
                    const Text('• Product Management', style: TextStyle(fontSize: 14)),
                    const Text('• Sales Management', style: TextStyle(fontSize: 14)),
                    const Text('• Purchase Management', style: TextStyle(fontSize: 14)),
                    const Text('• Reports & Analytics', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 12),
                    Text(
                      'Features:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const Text('• Auto-advance every 4 seconds', style: TextStyle(fontSize: 14)),
                    const Text('• Tap to pause/resume', style: TextStyle(fontSize: 14)),
                    const Text('• Skip button available', style: TextStyle(fontSize: 14)),
                    const Text('• Progress indicators', style: TextStyle(fontSize: 14)),
                    const Text('• Smooth animations', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}