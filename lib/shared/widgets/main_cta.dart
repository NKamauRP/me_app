import 'dart:math' as math;

import 'package:flutter/material.dart';

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
        // A very small repeating scale/glow keeps the primary task obvious
        // without turning the dashboard into a noisy animated screen.
        final t = Curves.easeInOut.transform(_pulseController.value);
        final glow = 18 + (12 * t);
        final scale = 1 + (0.012 * t);

        return Transform.scale(
          scale: scale,
          child: TapScale(
            onTap: widget.onTap,
            scaleDown: 0.985,
            child: GlassPanel(
              padding: const EdgeInsets.all(22),
              tint: widget.accentColor.withValues(alpha: 0.14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: 0.18),
                      blurRadius: glow,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        widget.badgeLabel,
                        style: TextStyle(
                          color: widget.accentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontSize: 30),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.subtitle,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        _CtaOrb(
                          accentColor: widget.accentColor,
                          progress: t,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.psychology_alt_rounded,
                            color: widget.accentColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Mind Me is your next best action.',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ],
                    ),
                  ],
                ),
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
