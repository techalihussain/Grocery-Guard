import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _onboardingKey = 'onboarding_completed';
  
  /// Check if onboarding has been completed
  static Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }
  
  /// Mark onboarding as completed
  static Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }
  
  /// Reset onboarding (for testing purposes)
  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingKey);
  }
  
  /// Get the appropriate initial route based on onboarding status
  static Future<String> getInitialRoute() async {
    final isCompleted = await isOnboardingCompleted();
    return isCompleted ? '/login' : '/onboarding';
  }
}