import 'package:flutter/material.dart';

class CustomLogo extends StatelessWidget {
  final double size;
  final String? imagePath;
  final BoxFit fit;

  const CustomLogo({
    super.key,
    this.size = 120,
    this.imagePath = 'assets/mylogo.png', // Default logo path
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        imagePath!,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to a simple icon if image fails to load
          return Icon(Icons.store, size: size * 0.6, color: Colors.grey);
        },
      ),
    );
  }
}

// Animated version of the logo
class AnimatedCustomLogo extends StatefulWidget {
  final double size;
  final String? imagePath;
  final BoxFit fit;

  const AnimatedCustomLogo({
    super.key,
    this.size = 120,
    this.imagePath = 'assets/mylogo.png',
    this.fit = BoxFit.contain,
  });

  @override
  State<AnimatedCustomLogo> createState() => _AnimatedCustomLogoState();
}

class _AnimatedCustomLogoState extends State<AnimatedCustomLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Start the continuous animation
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: CustomLogo(
            size: widget.size,
            imagePath: widget.imagePath,
            fit: widget.fit,
          ),
        );
      },
    );
  }
}
