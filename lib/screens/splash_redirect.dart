import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/onboarding_service.dart';
import '../../widgets/custom_logo.dart';

class SplashRedirector extends StatefulWidget {
  const SplashRedirector({super.key});

  @override
  State<SplashRedirector> createState() => _SplashRedirectorState();
}

class _SplashRedirectorState extends State<SplashRedirector>
    with TickerProviderStateMixin {
  // Animation Controllers
  late AnimationController _backgroundController;
  late AnimationController _iconController;
  late AnimationController _textController;
  late AnimationController _loadingController;

  // Animations
  late Animation<double> _backgroundAnimation;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _iconRotationAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _loadingAnimation;

  // Loading states
  String _loadingText = 'Initializing...';
  bool _showLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimationSequence();
  }

  void _initializeAnimations() {
    // Background gradient animation (2 seconds)
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut),
    );

    // Icon animation (1.5 seconds)
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _iconScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.elasticOut),
    );
    _iconRotationAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeInOut),
    );

    // Text animation (800ms)
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _textSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
        );
    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );

    // Loading animation (continuous)
    _loadingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _loadingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeInOut),
    );
  }

  void _startAnimationSequence() async {
    // Start background animation immediately
    _backgroundController.forward();

    // Wait 300ms, then start icon animation
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) _iconController.forward();

    // Wait 600ms, then start text animation
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) _textController.forward();

    // Wait 400ms, then show loading and start auth check
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() {
        _showLoading = true;
        _loadingText = 'Checking authentication...';
      });
      _loadingController.repeat();
      _handleRedirect();
    }
  }

  void _handleRedirect() async {
    try {
      // First check if onboarding has been completed
      if (mounted) {
        setState(() {
          _loadingText = 'Checking first launch...';
        });
      }

      final isOnboardingCompleted = await OnboardingService.isOnboardingCompleted();

      if (!mounted) return;

      // If onboarding not completed, show onboarding
      if (!isOnboardingCompleted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/onboarding');
        }
        return;
      }

      // If onboarding completed, proceed with authentication check
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Wait for auth provider to be initialized
      if (mounted) {
        setState(() {
          _loadingText = 'Initializing authentication...';
        });
      }

      // Wait for auth to be initialized with timeout
      int attempts = 0;
      while (!authProvider.isInitialized && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
        if (!mounted) return;
      }

      // Update loading text
      if (mounted) {
        setState(() {
          _loadingText = 'Checking authentication...';
        });
      }

      // Clear any previous errors before checking auth
      authProvider.clear();

      final role = await authProvider.checkAuthAndGetRole();

      if (!mounted) return;

      // Check for errors
      if (authProvider.error != null) {
        if (mounted) {
          setState(() {
            _loadingText = 'Authentication error, redirecting to sign in...';
          });
        }
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/signIn');
        }
        return;
      }

      // Update loading text
      if (mounted) {
        setState(() {
          _loadingText = role != null ? 'Loading your dashboard...' : 'Redirecting to sign in...';
        });
      }

      // Small delay to show the loading animation
      await Future.delayed(const Duration(milliseconds: 500));

      if (role != null && mounted) {
        Navigator.pushReplacementNamed(context, '/$role');
      } else if (mounted) {
        Navigator.pushReplacementNamed(context, '/signIn');
      }
    } catch (e) {
      // Handle any unexpected errors
      if (mounted) {
        setState(() {
          _loadingText = 'Error occurred, redirecting to sign in...';
        });
      }
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/signIn');
      }
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _iconController.dispose();
    _textController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _backgroundAnimation,
          _iconScaleAnimation,
          _textFadeAnimation,
          _loadingAnimation,
        ]),
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    Colors.blue.shade50,
                    Colors.blue.shade400,
                    _backgroundAnimation.value * 0.8,
                  )!,
                  Color.lerp(
                    Colors.purple.shade50,
                    Colors.purple.shade400,
                    _backgroundAnimation.value * 0.6,
                  )!,
                  Color.lerp(
                    Colors.indigo.shade50,
                    Colors.indigo.shade500,
                    _backgroundAnimation.value * 0.7,
                  )!,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Animated Custom Logo with Scale-up Effect
                  Transform.scale(
                    scale:
                        _iconScaleAnimation.value *
                        _iconRotationAnimation.value,
                    child: const CustomLogo(
                      size: 120,
                      imagePath: 'assets/mylogo.png',
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Animated App Name
                  SlideTransition(
                    position: _textSlideAnimation,
                    child: FadeTransition(
                      opacity: _textFadeAnimation,
                      child: Column(
                        children: [
                          Text(
                            'Grocery Guard',
                            style: TextStyle(
                              fontSize: size.width > 400 ? 34 : 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'A Store Manager',
                            style: TextStyle(
                              fontSize: size.width > 400 ? 32 : 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Professional Business Management',
                            style: TextStyle(
                              fontSize: size.width > 400 ? 16 : 14,
                              color: Colors.white.withValues(alpha: 0.9),
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 5,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Animated Loading Section
                  if (_showLoading) ...[
                    // Custom Loading Indicator
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Rotating outer ring
                          Transform.rotate(
                            angle: _loadingAnimation.value * 2 * 3.14159,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: CustomPaint(
                                painter: LoadingPainter(
                                  _loadingAnimation.value,
                                ),
                              ),
                            ),
                          ),
                          // Inner dot
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Loading Text
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _loadingText,
                        key: ValueKey(_loadingText),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 5,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 50),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Custom Painter for Loading Animation
class LoadingPainter extends CustomPainter {
  final double progress;

  LoadingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Draw animated arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2, // Start from top
      2 * 3.14159 * 0.7, // 70% of circle
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(LoadingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
