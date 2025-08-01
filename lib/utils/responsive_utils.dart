import 'package:flutter/material.dart';

class ResponsiveUtils {
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 400;
  }

  static bool isMediumScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 400 && 
           MediaQuery.of(context).size.width < 800;
  }

  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 800;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width > 600;
  }

  static double getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return 16.0;
    if (width < 800) return 24.0;
    return 32.0;
  }

  static EdgeInsets getResponsiveMargin(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return const EdgeInsets.all(8.0);
    if (width < 800) return const EdgeInsets.all(16.0);
    return const EdgeInsets.all(24.0);
  }

  static int getGridCrossAxisCount(BuildContext context, {int defaultCount = 2}) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return 1;
    if (width < 600) return defaultCount;
    if (width < 900) return defaultCount + 1;
    return defaultCount + 2;
  }

  static double getGridChildAspectRatio(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return 2.5; // Wider cards on small screens
    return 1.0; // Square cards on larger screens
  }

  static double getDialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 400) return screenWidth * 0.95;
    if (screenWidth < 800) return screenWidth * 0.8;
    return 600.0; // Max width for large screens
  }

  static bool shouldStackVertically(BuildContext context, {double threshold = 400}) {
    return MediaQuery.of(context).size.width < threshold;
  }

  static TextStyle getResponsiveTextStyle(BuildContext context, {
    double baseSize = 16.0,
    FontWeight? fontWeight,
    Color? color,
  }) {
    final width = MediaQuery.of(context).size.width;
    double fontSize = baseSize;
    
    if (width < 400) {
      fontSize = baseSize * 0.9;
    } else if (width > 800) {
      fontSize = baseSize * 1.1;
    }

    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}

// Extension for easier access
extension ResponsiveContext on BuildContext {
  bool get isSmallScreen => ResponsiveUtils.isSmallScreen(this);
  bool get isMediumScreen => ResponsiveUtils.isMediumScreen(this);
  bool get isLargeScreen => ResponsiveUtils.isLargeScreen(this);
  bool get isTablet => ResponsiveUtils.isTablet(this);
  
  double get responsivePadding => ResponsiveUtils.getResponsivePadding(this);
  EdgeInsets get responsiveMargin => ResponsiveUtils.getResponsiveMargin(this);
  
  int gridCrossAxisCount([int defaultCount = 2]) => 
      ResponsiveUtils.getGridCrossAxisCount(this, defaultCount: defaultCount);
  
  double get gridChildAspectRatio => ResponsiveUtils.getGridChildAspectRatio(this);
  double get dialogWidth => ResponsiveUtils.getDialogWidth(this);
  
  bool shouldStackVertically([double threshold = 400]) => 
      ResponsiveUtils.shouldStackVertically(this, threshold: threshold);
}