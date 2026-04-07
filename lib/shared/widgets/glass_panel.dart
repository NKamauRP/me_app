import 'dart:ui';

import 'package:flutter/material.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 28,
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
    final baseSurface = theme.colorScheme.surface.withValues(
      alpha: isDark ? 0.94 : 0.96,
    );

    // Blend tint into the current surface instead of replacing it. This keeps
    // dark themes readable and prevents pale mood colors from turning the panel
    // into a giant grey sheet.
    final tintOverlay = (tint ?? theme.colorScheme.primary).withValues(
      alpha: isDark ? 0.14 : 0.08,
    );
    final blendedSurface = Color.alphaBlend(tintOverlay, baseSurface);
    final topColor = blendedSurface.withValues(alpha: isDark ? 0.84 : 0.90);
    final bottomColor = Color.alphaBlend(
      theme.colorScheme.surface.withValues(alpha: isDark ? 0.12 : 0.04),
      blendedSurface,
    ).withValues(alpha: isDark ? 0.74 : 0.82);
    final outlineColor = (tint ?? theme.colorScheme.onSurface).withValues(
      alpha: isDark ? 0.14 : 0.08,
    );

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  topColor,
                  bottomColor,
                ],
              ),
              border: Border.all(color: outlineColor),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
