import 'dart:ui';
import 'package:flutter/material.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 22,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Claude/Notion style: subtle elevation instead of heavy blur
    final baseSurface = theme.colorScheme.surface;
    final outlineColor = (tint ?? theme.colorScheme.onSurface).withValues(
      alpha: isDark ? 0.12 : 0.06,
    );

    return Container(
      decoration: BoxDecoration(
        color: baseSurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: outlineColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4), // Reduced blur for professional feel
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: (tint ?? theme.colorScheme.primary).withValues(
                alpha: isDark ? 0.05 : 0.02,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
