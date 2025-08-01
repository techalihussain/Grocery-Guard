import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/onboarding_model.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  Timer? _autoAdvanceTimer;
  int _currentPage = 0;
  bool _isAutoAdvancing = true;

  // Animation controllers
  late AnimationController _progressController;
  late AnimationController _fadeController;
  late AnimationController _titleController;
  late AnimationController _subtitleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _titleAnimation;
  late Animation<double> _subtitleAnimation;

  // Auto-advance duration (configurable)
  static const Duration _autoAdvanceDuration = Duration(seconds: 6); // Increased for better performance

  // Onboarding pages data
  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: "Manage Users",
      subtitle: "Effortless Team Management",
      description: "Take control of your team with powerful user management features.",
      imagePath: "assets/user.png",
    ),
    OnboardingPage(
      title: "Product Management",
      subtitle: "Organize Your Inventory",
      description: "Master your inventory with intelligent product management.",
      imagePath: "assets/product.png",
    ),
    OnboardingPage(
      title: "Sales Management",
      subtitle: "Process Sales Efficiently",
      description: "Create sales invoices with ease and track customer payments.",
      imagePath: "assets/sale.png",
    ),
    OnboardingPage(
      title: "Purchase Management",
      subtitle: "Streamline Procurement",
      description: "Record purchases from vendors and manage payments seamlessly.",
      imagePath: "assets/purchase.png",
    ),
    OnboardingPage(
      title: "Reports & Analytics",
      subtitle: "Business Insights",
      description: "Get detailed reports with visual charts and comprehensive analytics.",
      imagePath: "assets/report.png",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAutoAdvance();
  }

  void _setupAnimations() {
    _progressController = AnimationController(
      duration: _autoAdvanceDuration,
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Reduced animation duration for better performance
    _titleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _subtitleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Use more efficient curves
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _titleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.linear),
    );

    _subtitleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _subtitleController, curve: Curves.linear),
    );

    _startPageAnimations();
  }

  void _startPageAnimations() {
    // Stagger animations to reduce GPU load
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _titleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _subtitleController.forward();
    });
  }

  void _resetAnimations() {
    _fadeController.reset();
    _titleController.reset();
    _subtitleController.reset();
    _startPageAnimations();
  }

  void _startAutoAdvance() {
    if (!_isAutoAdvancing) return;

    _progressController.reset();
    _progressController.forward();

    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(_autoAdvanceDuration, () {
      if (_isAutoAdvancing && mounted) {
        _nextPage();
      }
    });
  }

  void _pauseAutoAdvance() {
    setState(() {
      _isAutoAdvancing = false;
    });
    _autoAdvanceTimer?.cancel();
    _progressController.stop();
  }

  void _resumeAutoAdvance() {
    setState(() {
      _isAutoAdvancing = true;
    });
    _startAutoAdvance();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pauseAutoAdvance();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  void _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (mounted) {
      // Navigate to sign in screen after onboarding completion
      Navigator.pushReplacementNamed(context, '/signIn');
    }
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _progressController.dispose();
    _fadeController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _pageController.dispose();
    
    // Clear image cache to free memory
    imageCache.clear();
    imageCache.clearLiveImages();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RepaintBoundary(
        child: Stack(
          children: [
            // Main content with touch navigation
            GestureDetector(
              onTapUp: (details) {
                final screenWidth = MediaQuery.of(context).size.width;
                final tapPosition = details.globalPosition.dx;

                // Left side tap - go to previous page
                if (tapPosition < screenWidth * 0.3 && _currentPage > 0) {
                  _pauseAutoAdvance();
                  _previousPage();
                }
                // Right side tap - go to next page
                else if (tapPosition > screenWidth * 0.7) {
                  _pauseAutoAdvance();
                  _nextPage();
                }
                // Center tap - toggle auto-advance
                else {
                  if (_isAutoAdvancing) {
                    _pauseAutoAdvance();
                  } else {
                    _resumeAutoAdvance();
                  }
                }
              },
              child: PageView.builder(
                controller: _pageController,
                physics: const ClampingScrollPhysics(), // More efficient scrolling
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                  _resetAnimations();
                  if (_isAutoAdvancing) {
                    _startAutoAdvance();
                  }
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return RepaintBoundary(
                    child: _buildPage(_pages[index]),
                  );
                },
              ),
            ),

            // Skip button at top right
            RepaintBoundary(child: _buildSkipButton()),

            // Professional dots at bottom center
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: RepaintBoundary(child: _buildProfessionalDots()),
            ),

            // Touch zones indicators (for debugging)
            if (false) // Set to true to see touch zones
              ..._buildTouchZoneIndicators(),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Stack(
      children: [
        // Full-screen image background with optimization
        Positioned.fill(
          child: RepaintBoundary(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Image.asset(
                page.imagePath,
                fit: BoxFit.cover,
                cacheWidth: 800, // Limit image resolution for better performance
                cacheHeight: 1200,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.shade600,
                          Colors.purple.shade600,
                          Colors.indigo.shade700,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _getIconForPage(page.title),
                        size: 200,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Dark overlay for better text readability
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.5),
                ],
              ),
            ),
          ),
        ),

        // Title text overlay - Top Left
        Positioned(
          top: 100,
          left: 24,
          right: MediaQuery.of(context).size.width * 0.2,
          child: _buildAnimatedText(
            text: page.title,
            controller: _titleController,
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -1.0,
              height: 1.1,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.8),
                  blurRadius: 15,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: TextAlign.left,
          ),
        ),

        // Subtitle text overlay - Bottom Right
        if (page.subtitle != null)
          Positioned(
            bottom: 140,
            right: 24,
            left: MediaQuery.of(context).size.width * 0.2,
            child: _buildAnimatedText(
              text: page.subtitle!,
              controller: _subtitleController,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
                height: 1.2,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: TextAlign.right,
            ),
          ),
      ],
    );
  }

  // Ultra-optimized animated text widget (minimal GPU load)
  Widget _buildAnimatedText({
    required String text,
    required AnimationController controller,
    required TextStyle style,
    TextAlign alignment = TextAlign.left,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // Simple fade-in instead of character-by-character for better performance
        return RepaintBoundary(
          child: Opacity(
            opacity: controller.value,
            child: Text(
              text,
              style: style,
              textAlign: alignment,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkipButton() {
    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: 20, right: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Simple skip text
            GestureDetector(
              onTap: _skipOnboarding,
              child: Text(
                'Skip',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.7),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalDots() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pages.length, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            child: _buildProfessionalDot(index),
          );
        }),
      ),
    );
  }

  Widget _buildProfessionalDot(int index) {
    final isActive = index == _currentPage;
    final isCompleted = index < _currentPage;

    return GestureDetector(
      onTap: () {
        _pauseAutoAdvance();
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: isActive ? 40 : 12,
        height: 12,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: isCompleted || isActive
              ? Colors.white
              : Colors.white.withOpacity(0.4),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: isActive && _isAutoAdvancing
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: _progressController.value,
                      backgroundColor: Colors.white,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue.shade400,
                      ),
                    );
                  },
                ),
              )
            : null,
      ),
    );
  }

  List<Widget> _buildTouchZoneIndicators() {
    return [
      // Left touch zone
      Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: MediaQuery.of(context).size.width * 0.3,
        child: Container(
          color: Colors.red.withOpacity(0.1),
          child: const Center(
            child: Icon(Icons.arrow_back, color: Colors.red, size: 40),
          ),
        ),
      ),
      // Right touch zone
      Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        width: MediaQuery.of(context).size.width * 0.3,
        child: Container(
          color: Colors.green.withOpacity(0.1),
          child: const Center(
            child: Icon(Icons.arrow_forward, color: Colors.green, size: 40),
          ),
        ),
      ),
      // Center touch zone
      Positioned(
        left: MediaQuery.of(context).size.width * 0.3,
        right: MediaQuery.of(context).size.width * 0.3,
        top: 0,
        bottom: 0,
        child: Container(
          color: Colors.blue.withOpacity(0.1),
          child: Center(
            child: Icon(
              _isAutoAdvancing ? Icons.pause : Icons.play_arrow,
              color: Colors.blue,
              size: 40,
            ),
          ),
        ),
      ),
    ];
  }

  IconData _getIconForPage(String title) {
    switch (title) {
      case "Manage Users":
        return Icons.people;
      case "Product Management":
        return Icons.inventory;
      case "Sales Management":
        return Icons.point_of_sale;
      case "Purchase Management":
        return Icons.shopping_cart;
      case "Reports & Analytics":
        return Icons.analytics;
      default:
        return Icons.info;
    }
  }
}