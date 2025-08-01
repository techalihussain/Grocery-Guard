import 'package:flutter/material.dart';

import '../utils/responsive_utils.dart';

class GlobalDashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isResponsive;
  final double? elevation;
  final EdgeInsets? padding;
  final double? iconSize;
  final TextStyle? titleStyle;
  final String? subtitle;
  final Widget? badge;
  final bool showGradient;
  final BorderRadius? borderRadius;

  const GlobalDashboardCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isResponsive = true,
    this.elevation = 8,
    this.padding,
    this.iconSize,
    this.titleStyle,
    this.subtitle,
    this.badge,
    this.showGradient = true,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding =
        padding ??
        (isResponsive
            ? EdgeInsets.all(context.responsivePadding * 0.75)
            : const EdgeInsets.all(12));

    final effectiveIconSize =
        iconSize ??
        (isResponsive ? (context.isSmallScreen ? 28.0 : 32.0) : 26.0);

    final effectiveTitleStyle =
        titleStyle ??
        (isResponsive
            ? ResponsiveUtils.getResponsiveTextStyle(
                context,
                baseSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              )
            : TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ));

    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(16);

    return Card(
      elevation: elevation,
      shadowColor: color.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: effectiveBorderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: effectiveBorderRadius,
        child: Container(
          padding: effectivePadding,
          decoration: BoxDecoration(
            borderRadius: effectiveBorderRadius,
            gradient: showGradient
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.1),
                      color.withValues(alpha: 0.05),
                    ],
                  )
                : null,
            color: showGradient ? null : color.withValues(alpha: 0.1),
          ),
          child: Stack(
            children: [
              // Badge positioned at top-right if provided
              if (badge != null) Positioned(top: 0, right: 0, child: badge!),
              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.all(
                          isResponsive ? (context.isSmallScreen ? 12 : 16) : 10,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(
                            isResponsive ? 12 : 10,
                          ),
                        ),
                        child: Icon(
                          icon,
                          size: effectiveIconSize,
                          color: color,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: isResponsive
                          ? (context.isSmallScreen ? 8 : 12)
                          : 10,
                    ),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: effectiveTitleStyle,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle!,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isResponsive
                                    ? (context.isSmallScreen ? 12 : 14)
                                    : 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
