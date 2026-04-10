import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/services/theme_service.dart';
import '../../features/mind/micro_interactions.dart';
import 'glass_panel.dart';

class MainCta extends StatefulWidget {
  const MainCta({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badgeLabel;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<MainCta> createState() => _MainCtaState();
}

class _MainCtaState extends State<MainCta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final settings = context.watch<ThemeService>();
        final palette = AppTheme.paletteOf(settings.currentTheme);
        final t = Curves.easeInOut.transform(_pulseController.value);

        return TapScale(
          onTap: widget.onTap,
          scaleDown: 0.98,
          child: Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.accentColor.withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Opacity(
                      opacity: 0.08,
                      child: _CtaOrb(
                        accentColor: widget.accentColor,
                        progress: t,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.badgeLabel.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: widget.accentColor,
                                  fontSize: 10,
                                ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.subtitle,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontSize: 15,
                                height: 1.5,
                              ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Text(
                              'Start reflection',
                              style: TextStyle(
                                color: widget.accentColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: widget.accentColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CtaOrb extends StatelessWidget {
  const _CtaOrb({
    required this.accentColor,
    required this.progress,
  });

  final Color accentColor;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      width: 92,
      child: CustomPaint(
        painter: _OrbPainter(
          accentColor: accentColor,
          progress: progress,
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  const _OrbPainter({
    required this.accentColor,
    required this.progress,
  });

  final Color accentColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.12 + (0.08 * progress))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, radius * 0.68, glowPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..shader = SweepGradient(
        colors: [
          accentColor.withValues(alpha: 0.22),
          accentColor,
          accentColor.withValues(alpha: 0.22),
        ],
        transform: GradientRotation(progress * math.pi),
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, radius * 0.44, ringPaint);

    final fillPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.16);
    canvas.drawCircle(center, radius * 0.34, fillPaint);

    final iconPainter = TextPainter(
      text: TextSpan(
        text: '•',
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: accentColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      Offset(
        center.dx - iconPainter.width / 2,
        center.dy - iconPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor;
  }
}
